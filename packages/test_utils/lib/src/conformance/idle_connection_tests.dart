import 'dart:async';
import 'dart:convert';

import 'package:async/async.dart';
import 'package:relic_core/relic_core.dart';
import 'package:test/test.dart';
import 'package:web_socket/web_socket.dart';

import 'conformance.dart';

/// How long a connection sits idle between two of its messages.
const _quiet = Duration(milliseconds: 200);

const _timeout = Duration(seconds: 5);

void idleConnectionTests(AdapterConformance conformance) {
  group('Given a connection that sits idle between two messages', () {
    RelicServer? server;

    tearDown(() async {
      await server?.close(force: true);
      server = null;
    });

    test('when a keep-alive request follows an answered one, '
        'then it is answered on the same connection', () async {
      server = await conformance.serve(
        (req) => Response.ok(body: Body.fromString('ok')),
      );
      final socket = await conformance.connect(server!.port);
      addTearDown(socket.destroy);
      final received = StringBuffer();
      final answered = Completer<void>();
      final closed = Completer<void>();
      utf8.decoder
          .bind(socket)
          .listen(
            (chunk) {
              received.write(chunk);
              if (!answered.isCompleted && '$received'.contains('\r\n\r\nok')) {
                answered.complete();
              }
            },
            onError: closed.completeError,
            onDone: closed.complete,
          );

      socket.write('GET / HTTP/1.1\r\nHost: x\r\n\r\n');
      await answered.future.timeout(_timeout);
      await Future<void>.delayed(_quiet);
      socket.write('GET / HTTP/1.1\r\nHost: x\r\nConnection: close\r\n\r\n');
      await closed.future.timeout(_timeout);

      final (head: first, body: rest) = splitHead('$received');
      expect(first, startsWith('HTTP/1.1 200'));
      expect(rest, startsWith('ok'));
      final (head: second, body: last) = splitHead(rest.substring(2));
      expect(second, startsWith('HTTP/1.1 200'));
      expect(last, 'ok');
    });

    test('when a WebSocket message follows an echoed one, '
        'then it is echoed too', () async {
      server = await conformance.serve(
        (req) => WebSocketUpgrade((serverSocket) async {
          await for (final event in serverSocket.events) {
            if (event is TextDataReceived) serverSocket.sendText(event.text);
          }
        }),
      );
      final client = await WebSocket.connect(
        Uri.parse('ws://localhost:${server!.port}'),
      );
      final events = StreamQueue(client.events);

      client.sendText('first');
      expect(await events.next.timeout(_timeout), TextDataReceived('first'));
      await Future<void>.delayed(_quiet);
      client.sendText('second');
      expect(await events.next.timeout(_timeout), TextDataReceived('second'));

      await client.close();
    }, skip: conformance.skipWebSocket);
  });
}
