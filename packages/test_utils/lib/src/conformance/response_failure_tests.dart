import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:http/http.dart' as http;
import 'package:relic_core/relic_core.dart';
import 'package:test/test.dart';

import 'conformance.dart';

void responseFailureTests(AdapterConformance conformance) {
  group('Given a handler whose response cannot be written', () {
    late RelicServer server;
    var handlerCompleted = false;

    setUp(() async {
      handlerCompleted = false;
      server = await conformance.serve((req) async {
        final response = Response.ok(
          body: Body.fromString(
            'x',
            mimeType: const MimeType('text', 'plain\r\nX-Injected: 1'),
          ),
        );
        handlerCompleted = true;
        return response;
      });
    });

    tearDown(() => server.close());

    test('when a request is made, '
        'then the client is answered rather than left waiting.', () async {
      final response = await http
          .get(Uri.http('localhost:${server.port}'))
          .timeout(
            const Duration(seconds: 5),
            onTimeout: () => fail(
              'The request was never answered. The response failed to write '
              'and the connection was left open instead of being closed.',
            ),
          );

      expect(response.statusCode, HttpStatus.internalServerError);
      expect(
        handlerCompleted,
        isTrue,
        reason:
            'The failure must happen while writing the response, '
            'not inside the handler',
      );
    });

    test('when several requests fail to write, '
        'then no connection is left active.', () async {
      for (var i = 0; i < 5; i++) {
        try {
          await http
              .get(Uri.http('localhost:${server.port}'))
              .timeout(const Duration(seconds: 5));
        } on TimeoutException {
          fail('Request $i was never answered; the connection is pinned.');
        }
      }

      Future<int> active() async => (await server.connectionsInfo()).active;
      final stopwatch = Stopwatch()..start();
      while (await active() != 0 &&
          stopwatch.elapsed < const Duration(seconds: 5)) {
        await Future<void>.delayed(const Duration(milliseconds: 10));
      }
      expect(
        await active(),
        0,
        reason: 'A response that failed to write must not pin its connection',
      );
      expect(
        handlerCompleted,
        isTrue,
        reason:
            'The failure must happen while writing the response, '
            'not inside the handler',
      );
    });
  });

  group(
    'Given a handler whose streamed body fails after the head went out',
    () {
      late RelicServer server;

      setUp(() async {
        server = await conformance.serve((req) {
          final body = StreamController<Uint8List>();
          body
            ..add(Uint8List.fromList(utf8.encode('partial')))
            ..addError(StateError('the source went away'))
            ..close();
          return Response.ok(body: Body.fromDataStream(body.stream));
        });
      });

      tearDown(() => server.close(force: true));

      test('when a request is made, '
          'then the connection is closed rather than left open.', () async {
        final reply = await rawExchange(
          server.port,
          'GET / HTTP/1.1\r\nHost: localhost\r\n\r\n',
        );

        expect(reply, startsWith('HTTP/1.1 200'));
      });

      test('when a request is made, '
          'then a graceful close completes.', () async {
        await rawExchange(
          server.port,
          'GET / HTTP/1.1\r\nHost: localhost\r\n\r\n',
        );

        await expectLater(
          server.close().timeout(const Duration(seconds: 5)),
          completes,
          reason:
              'A connection whose body failed to write must not be counted '
              'as in flight',
        );
      });
    },
  );
}
