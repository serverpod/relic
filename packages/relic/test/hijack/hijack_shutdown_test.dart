import 'dart:async';
import 'dart:convert';
import 'dart:io' as io;
import 'dart:typed_data';

import 'package:http/http.dart' as http;
import 'package:relic/relic.dart';
import 'package:test/test.dart';

import '../headers/headers_test_utils.dart';
import '../util/test_util.dart';

void main() {
  late RelicServer server;

  group('Given a hijacked connection', () {
    late Completer<void> hijacked;
    Stream<List<int>>? hijackedStream;

    setUp(() async {
      hijacked = Completer<void>();
      hijackedStream = null;
      server = await testServe(
        (final req) => Hijack((final channel) {
          hijackedStream = channel.stream;
          hijacked.complete();
        }),
      );

      unawaited(
        http
            .get(server.url)
            .timeout(const Duration(milliseconds: 200))
            .then<void>((final _) {}, onError: (final _) {}),
      );
      await hijacked.future;
    });

    test('when the server reports its connections, '
        'then the hijacked one is counted.', () async {
      final info = await server.connectionsInfo();

      expect(
        info.active,
        greaterThan(0),
        reason: 'A detached connection is still a connection the server owns',
      );

      await server.close(force: true);
    });

    test('when the server is closed forcefully, '
        'then the socket is closed too.', () async {
      final drained = hijackedStream!.drain<void>();

      await server.close(force: true);

      await expectLater(
        drained.timeout(const Duration(seconds: 2)),
        completes,
        reason: 'A forced shutdown must not leave the socket open',
      );
    });

    test('when the server is closed gracefully, '
        'then the socket is closed once the drain completes.', () async {
      await server.close();

      await expectLater(
        hijackedStream!.drain<void>().timeout(const Duration(seconds: 5)),
        completes,
        reason: 'A graceful shutdown must still finish closing the socket',
      );
    });
  });

  group('Given a hijacked connection whose peer stops reading,', () {
    late Completer<void> flooded;
    Stream<List<int>>? stream;
    late io.Socket client;

    setUp(() async {
      flooded = Completer<void>();
      stream = null;
      server = await testServe(
        (final req) => Hijack((final channel) {
          stream = channel.stream;
          final chunk = Uint8List(1 << 20);
          for (var i = 0; i < 64; i++) {
            channel.sink.add(chunk);
          }
          flooded.complete();
        }),
      );

      client = await io.Socket.connect(
        io.InternetAddress.loopbackIPv4,
        server.url.port,
      );
      client.write('GET / HTTP/1.1\r\nHost: x\r\n\r\n');
      await flooded.future;
    });

    tearDown(() async {
      client.destroy();
      await server.close(force: true);
    });

    test('when the server is closed gracefully, '
        'then the drain deadline still drops the connection.', () async {
      final drained = stream!.drain<void>();

      await server.close();

      await expectLater(
        drained.timeout(const Duration(seconds: 2)),
        completes,
        reason: 'A peer that never drains must be dropped, not leaked',
      );
    });

    test('when the server is closed forcefully, '
        'then it completes without waiting for the flush.', () async {
      final drained = stream!.drain<void>();

      await expectLater(
        server.close(force: true).timeout(const Duration(seconds: 2)),
        completes,
        reason: 'A forced close must not wait on an unflushable socket',
      );

      await expectLater(
        drained.timeout(const Duration(seconds: 2)),
        completes,
        reason: 'A forced shutdown must not leave the socket open',
      );
    });
  });

  group('Given an upgraded WebSocket whose peer ignores the close,', () {
    late Completer<void> connected;
    late io.Socket client;
    late StreamIterator<List<int>> incoming;

    setUp(() async {
      connected = Completer<void>();
      server = await testServe(
        (final req) => WebSocketUpgrade((final ws) => connected.complete()),
      );

      client = await io.Socket.connect(
        io.InternetAddress.loopbackIPv4,
        server.url.port,
      );
      incoming = StreamIterator(client);
      client.write(
        'GET / HTTP/1.1\r\n'
        'Host: x\r\n'
        'Upgrade: websocket\r\n'
        'Connection: Upgrade\r\n'
        'Sec-WebSocket-Key: ${base64.encode(List<int>.filled(16, 0))}\r\n'
        'Sec-WebSocket-Version: 13\r\n'
        '\r\n',
      );
      await connected.future;

      final consumed = <int>[];
      while (!utf8
          .decode(consumed, allowMalformed: true)
          .contains('\r\n\r\n')) {
        expect(
          await incoming.moveNext().timeout(const Duration(seconds: 2)),
          isTrue,
          reason: 'The upgrade handshake must complete',
        );
        consumed.addAll(incoming.current);
      }
    });

    tearDown(() async {
      client.destroy();
      await server.close(force: true);
    });

    test('when the server is closed forcefully, '
        'then it completes at once and the peer is told to go away.', () async {
      await expectLater(
        server.close(force: true).timeout(const Duration(seconds: 2)),
        completes,
        reason: 'A forced close must not await the close handshake',
      );

      final gotFrame = await incoming.moveNext().timeout(
        const Duration(seconds: 2),
        onTimeout: () => false,
      );
      expect(
        gotFrame,
        isTrue,
        reason: 'Destroying the WebSocket must still emit the close frame',
      );
    });
  });

  group('Given a connected WebSocket,', () {
    late Completer<void> connected;
    late io.WebSocket client;

    setUp(() async {
      connected = Completer<void>();
      server = await testServe(
        (final req) => WebSocketUpgrade((final ws) => connected.complete()),
      );
      client = await io.WebSocket.connect('ws://localhost:${server.url.port}');
      await connected.future;
    });

    tearDown(() => server.close(force: true));

    test('when the server reports its connections, '
        'then the upgraded one is counted.', () async {
      final info = await server.connectionsInfo();

      expect(
        info.active,
        greaterThan(0),
        reason: 'An upgraded connection is still a connection the server owns',
      );
    });

    test('when the server is closed gracefully, '
        'then the peer completes the going-away handshake.', () async {
      final drained = client.drain<void>();

      await server.close().timeout(const Duration(seconds: 2));

      await drained.timeout(const Duration(seconds: 2));
      expect(
        client.closeCode,
        1001,
        reason: 'A graceful shutdown must tell the peer it is going away',
      );
    });
  });
}
