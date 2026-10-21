import 'dart:convert';
import 'dart:io' as io;

import 'package:relic_core/relic_core.dart';
import 'package:test/test.dart';

import 'conformance.dart';

void webSocketOriginTests(AdapterConformance conformance) {
  group('Given a WebSocket endpoint', () {
    late RelicServer server;

    setUp(() async {
      server = await conformance.serve(
        (req) => WebSocketUpgrade((socket) async {
          await socket.close();
        }),
      );
    });

    tearDown(() => server.close());

    Future<int> handshakeStatus(String? origin) async {
      final client = io.HttpClient();
      try {
        final request = await client.openUrl(
          'GET',
          Uri.parse('http://localhost:${server.url.port}/'),
        );
        request.headers
          ..set('connection', 'Upgrade')
          ..set('upgrade', 'websocket')
          ..set('sec-websocket-version', '13')
          ..set(
            'sec-websocket-key',
            base64.encode(List.generate(16, (i) => i)),
          );
        if (origin != null) request.headers.set('origin', origin);
        final response = await request.close();
        await response.drain<void>();
        return response.statusCode;
      } finally {
        client.close(force: true);
      }
    }

    test('when a browser on another site opens it, '
        'then the upgrade is refused.', () async {
      expect(await handshakeStatus('https://evil.example'), 403);
    });

    test('when a page on the same host opens it, '
        'then the upgrade succeeds.', () async {
      expect(await handshakeStatus('http://localhost'), 101);
    });

    test('when a client sends no Origin, '
        'then the upgrade succeeds.', () async {
      expect(await handshakeStatus(null), 101);
    });

    test('when a client sends a HEAD, '
        'then it gets 405 with GET as the allowed method', () async {
      final reply = await rawExchange(
        server.url.port,
        'HEAD / HTTP/1.1\r\nHost: x\r\nConnection: close\r\n\r\n',
      );

      final (head: head, body: _) = splitHead(reply);
      expect(head, startsWith('HTTP/1.1 405'));
      expect(head.toLowerCase(), contains('allow: get\r\n'));
    });

    test('when the Origin cannot be parsed, '
        'then the upgrade is refused.', () async {
      expect(await handshakeStatus('not a url'), 403);
    });

    test('when the endpoint opts out with allowAnyOrigin, '
        'then a cross-origin upgrade succeeds.', () async {
      await server.close();
      server = await conformance.serve(
        (req) => WebSocketUpgrade((socket) async {
          await socket.close();
        }, allowAnyOrigin: true),
      );

      expect(await handshakeStatus('https://evil.example'), 101);
    });
  }, skip: conformance.skipWebSocket);
}
