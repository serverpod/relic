import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:relic_core/relic_core.dart';
import 'package:test/test.dart';

import 'native_test_helpers.dart';

void main() {
  group('Given a client that resets its connection while the handler runs,', () {
    late RelicServer server;
    late Completer<void> arrived;
    late Completer<void> reset;
    late Result Function() answer;

    setUp(() async {
      arrived = Completer<void>();
      reset = Completer<void>();
      server = await serveNative((_) async {
        arrived.complete();
        await reset.future;
        return answer();
      });
    });

    tearDown(() => server.close(force: true));

    /// Sends [request] and resets the connection once the handler has it.
    /// The handler answers after the reset reached the server.
    Future<void> sendAndReset(String request) async {
      final socket = await Socket.connect(
        InternetAddress.loopbackIPv4,
        server.port,
      );
      socket.write(request);
      await socket.flush();
      await arrived.future.timeout(const Duration(seconds: 3));
      resetConnection(socket);
      await Future<void>.delayed(const Duration(milliseconds: 100));
      reset.complete();
    }

    test(
      'when the handler upgrades to a WebSocket, '
      'then the socket ends.',
      () async {
        final upgraded = Completer<RelicWebSocket>();
        answer = () => WebSocketUpgrade(upgraded.complete);

        await sendAndReset(webSocketUpgradeRequest);

        final socket = await upgraded.future.timeout(
          const Duration(seconds: 3),
        );
        await socket.done.timeout(const Duration(seconds: 3));
      },
      skip: Platform.isWindows
          // resetConnection sends a FIN there, so the 101 goes out and the
          // socket ends at the peer's EOF instead of the failed write.
          ? 'dart:io cannot reset a connection on Windows'
          : null,
    );

    test(
      'when the handler streams a response with a head bigger than the write buffer, '
      'then the body stream is cancelled.',
      () async {
        final cancelled = Completer<void>();
        final body = StreamController<Uint8List>(onCancel: cancelled.complete);
        answer = () => Response.ok(
          headers: Headers.build((mh) => mh['x-big'] = ['v' * (32 << 10)]),
          body: Body.fromDataStream(body.stream),
        );

        await sendAndReset('GET / HTTP/1.1\r\nHost: localhost\r\n\r\n');

        await cancelled.future.timeout(const Duration(seconds: 3));
      },
      skip: Platform.isWindows
          // resetConnection sends a FIN there, so the head goes out and
          // nothing fails while the body stays silent.
          ? 'dart:io cannot reset a connection on Windows'
          : null,
    );
  });
}
