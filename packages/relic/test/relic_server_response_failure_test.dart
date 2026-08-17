import 'dart:async';
import 'dart:io';

import 'package:http/http.dart' as http;
import 'package:relic/relic.dart';
import 'package:test/test.dart';

void main() {
  group('Given a handler whose response cannot be written', () {
    late RelicServer server;

    setUp(() async {
      server = RelicServer(
        () => IOAdapter.bind(InternetAddress.loopbackIPv4, port: 0),
      );
      await server.mountAndStart(
        (final req) async => Response.ok(
          headers: Headers.build(
            (final mh) => mh['x-reflected'] = ['a\r\nX-Injected: 1'],
          ),
        ),
      );
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
    });
  });
}
