import 'dart:convert';
import 'dart:io' as io;

import 'package:relic_core/relic_core.dart';
import 'package:test/test.dart';

import '../util/test_util.dart';

void main() {
  late RelicServer server;

  setUp(() async {
    server = await testServe(
      (final req) => WebSocketUpgrade((final socket) async {
        await socket.close();
      }),
    );
  });

  tearDown(() => server.close());

  Future<int> handshakeStatus(final String? origin) async {
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
          base64.encode(List.generate(16, (final i) => i)),
        );
      if (origin != null) request.headers.set('origin', origin);
      final response = await request.close();
      await response.drain<void>();
      return response.statusCode;
    } finally {
      client.close(force: true);
    }
  }

  group('Given a WebSocket endpoint', () {
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

    test('when the Origin cannot be parsed, '
        'then the upgrade is refused.', () async {
      expect(await handshakeStatus('not a url'), 403);
    });

    test('when the endpoint opts out with allowAnyOrigin, '
        'then a cross-origin upgrade succeeds.', () async {
      await server.close();
      server = await testServe(
        (final req) => WebSocketUpgrade((final socket) async {
          await socket.close();
        }, allowAnyOrigin: true),
      );

      expect(await handshakeStatus('https://evil.example'), 101);
    });
  });
}
