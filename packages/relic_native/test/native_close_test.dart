import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:http/http.dart' as http;
import 'package:relic_core/relic_core.dart';
import 'package:stream_channel/stream_channel.dart';
import 'package:test/test.dart';

import 'native_test_helpers.dart';

void main() {
  late RelicServer server;

  tearDown(() => server.close(force: true));

  test('Given an in-flight request and a hijacked connection, '
      'when the server closes gracefully and both finish, '
      'then close completes without waiting out the drain deadline', () async {
    final holding = Completer<void>();
    final release = Completer<void>();
    final hijacked = Completer<StreamChannel<Uint8List>>();
    server = await serveNative((req) {
      if (req.url.path == '/hold') {
        holding.complete();
        return release.future.then((_) => Response.ok());
      }
      return Hijack(hijacked.complete);
    });

    final held = http.get(Uri.http('127.0.0.1:${server.port}', '/hold'));
    final raw = await Socket.connect('127.0.0.1', server.port);
    raw.write('GET /raw HTTP/1.1\r\nHost: x\r\n\r\n');
    await raw.flush();
    await hijacked.future;
    await holding.future;
    unawaited(raw.drain<void>());

    final closing = server.close();
    release.complete();

    await expectLater(closing.timeout(const Duration(seconds: 3)), completes);
    expect((await held).statusCode, 200);
    raw.destroy();
  });

  test(
    'Given a hijacked connection whose sink was closed with bytes still to flush, '
    'when the peer half-closes meanwhile, '
    'then the sink is done only once the bytes went out',
    () async {
      final payload = Uint8List(64 << 20);
      final sinkDone = Completer<void>();
      server = await serveNative(
        (req) => Hijack((channel) {
          channel.sink.add(payload);
          sinkDone.complete(channel.sink.close());
        }),
      );

      final raw = await Socket.connect('127.0.0.1', server.port);
      raw.write('GET /raw HTTP/1.1\r\nHost: x\r\n\r\n');
      await raw.flush();
      var received = 0;
      var halfClosed = false;
      final drained = raw.listen((chunk) {
        received += chunk.length;
        if (halfClosed) return;
        halfClosed = true;
        // The peer is done sending. The native reader sees EOF while
        // the writer is still flushing.
        unawaited(raw.close());
      }, onError: (_) {}).asFuture<void>();

      await sinkDone.future.timeout(const Duration(seconds: 10));
      await server.close();
      await drained.timeout(const Duration(seconds: 10));

      expect(received, payload.length);
    },
  );
}
