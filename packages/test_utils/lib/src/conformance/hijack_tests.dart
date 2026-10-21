import 'dart:async';
import 'dart:convert';
import 'dart:io' as io;
import 'dart:typed_data';

import 'package:http/http.dart' as http;
import 'package:relic_core/relic_core.dart';
import 'package:test/test.dart';

import 'conformance.dart';

void hijackTests(AdapterConformance conformance) {
  late RelicServer server;

  test('Given a handler that hijacks and never writes, '
      'when a request is made, '
      'then the client times out waiting for a response', () async {
    server = await conformance.serve((req) {
      final result = Hijack((_) {});
      expect(result, isA<Hijack>());
      return result;
    });
    addTearDown(
      () => server.close(force: true).timeout(const Duration(seconds: 5)),
    );

    final request = http.Request(Method.get.value, server.url);
    await expectLater(
      request.send().timeout(const Duration(seconds: 1)),
      throwsA(isA<TimeoutException>()),
    );
  }, skip: conformance.skipHijack);

  test('Given a chunked request body, '
      'when the handler hijacks without reading it, '
      'then the server answers 500', () async {
    server = await conformance.serve((req) => Hijack((channel) {}));
    addTearDown(() => server.close(force: true));

    final reply = await rawExchange(
      server.port,
      'POST / HTTP/1.1\r\nHost: x\r\nTransfer-Encoding: chunked\r\n'
      'Connection: close\r\n\r\n5\r\nhello\r\n0\r\n\r\n',
    );

    expect(reply, startsWith('HTTP/1.1 500'));
  }, skip: conformance.skipHijack);

  test('Given a chunked request body, '
      'when the handler reads it to its end and hijacks, '
      'then the channel starts after the body', () async {
    server = await conformance.serve((req) async {
      await req.body.read().drain<void>();
      return Hijack((channel) {
        channel.stream.listen(channel.sink.add, onDone: channel.sink.close);
      });
    });
    addTearDown(() => server.close(force: true));

    final socket = await io.Socket.connect(
      io.InternetAddress.loopbackIPv4,
      server.port,
    );
    socket.write(
      'POST / HTTP/1.1\r\nHost: x\r\nTransfer-Encoding: chunked\r\n\r\n'
      '5\r\nhello\r\n0\r\n\r\nping',
    );
    await socket.flush();
    final echoed = utf8.decode(
      await socket.first.timeout(const Duration(seconds: 5)),
    );
    socket.destroy();

    expect(echoed, 'ping');
  }, skip: conformance.skipHijack ?? conformance.skipPipelined);

  test('Given a request body with a Content-Length, '
      'when the handler hijacks without reading it, '
      'then the body comes first on the channel', () async {
    server = await conformance.serve(
      (req) => Hijack((channel) {
        channel.stream.listen(channel.sink.add, onDone: channel.sink.close);
      }),
    );
    addTearDown(() => server.close(force: true));

    final socket = await io.Socket.connect(
      io.InternetAddress.loopbackIPv4,
      server.port,
    );
    socket.write(
      'POST / HTTP/1.1\r\nHost: x\r\nContent-Length: 5\r\n\r\nhello',
    );
    await socket.flush();
    final echoed = utf8.decode(
      await socket.first.timeout(const Duration(seconds: 5)),
    );
    socket.destroy();

    expect(echoed, 'hello');
  }, skip: conformance.skipHijack);

  group('Given a hijacked connection', () {
    late Completer<void> hijacked;
    Stream<List<int>>? hijackedStream;

    setUp(() async {
      hijacked = Completer<void>();
      hijackedStream = null;
      server = await conformance.serve(
        (req) => Hijack((channel) {
          hijackedStream = channel.stream;
          hijacked.complete();
        }),
      );

      unawaited(
        http
            .get(server.url)
            .timeout(const Duration(milliseconds: 200))
            .then<void>((_) {}, onError: (_) {}),
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
  }, skip: conformance.skipHijack);

  group(
    'Given a hijacked connection whose peer stops reading,',
    skip: conformance.skipHijack,
    () {
      late Completer<void> flooded;
      Stream<List<int>>? stream;
      late io.Socket client;

      setUp(() async {
        flooded = Completer<void>();
        stream = null;
        server = await conformance.serve(
          (req) => Hijack((channel) {
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

      test('when the server is closed gracefully and then forcefully, '
          'then the graceful close waits and the forced close drops the '
          'connection.', () async {
        final drained = stream!.drain<void>();

        final graceful = server.close();

        await expectLater(
          graceful.timeout(const Duration(milliseconds: 500)),
          throwsA(isA<TimeoutException>()),
          reason: 'A graceful close waits for a hijacked channel to flush',
        );

        await server.close(force: true);

        await expectLater(
          graceful.timeout(const Duration(seconds: 2)),
          completes,
          reason: 'A forced close must end the graceful one',
        );
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
    },
  );

  group(
    'Given an upgraded WebSocket whose peer ignores the close,',
    skip: conformance.skipWebSocket,
    () {
      late Completer<void> connected;
      late io.Socket client;
      late StreamIterator<List<int>> incoming;

      setUp(() async {
        connected = Completer<void>();
        server = await conformance.serve(
          (req) => WebSocketUpgrade((ws) => connected.complete()),
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

      test(
        'when the server is closed forcefully, '
        'then it completes at once and the peer is told to go away.',
        () async {
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
        },
      );
    },
  );

  group('Given a connected WebSocket,', () {
    late Completer<void> connected;
    late io.WebSocket client;

    setUp(() async {
      connected = Completer<void>();
      server = await conformance.serve(
        (req) => WebSocketUpgrade((ws) => connected.complete()),
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
  }, skip: conformance.skipWebSocket);
}
