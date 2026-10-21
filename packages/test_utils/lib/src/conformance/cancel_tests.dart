import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:http/http.dart' as http;
import 'package:relic_core/relic_core.dart';
import 'package:test/test.dart';

import 'conformance.dart';

/// [Request.cancelled] tells a handler the peer went away, on every
/// adapter.
void cancelTests(AdapterConformance conformance) {
  RelicServer? server;

  tearDown(() async {
    await server?.close(force: true);
    server = null;
  });

  Future<void> serve(Handler handler) async {
    server = await conformance.serve(handler);
  }

  Future<Socket> connect() =>
      Socket.connect(InternetAddress.loopbackIPv4, server!.port);

  test('Given a handler waiting on cancelled, when the peer hangs up, '
      'then cancelled completes while the handler still runs', () async {
    final sawCancel = Completer<void>();
    final release = Completer<void>();
    await serve((req) async {
      unawaited(req.cancelled.then((_) => sawCancel.complete()));
      await release.future;
      return Response.ok();
    });

    final socket = await connect();
    socket.write('GET / HTTP/1.1\r\nHost: x\r\n\r\n');
    await socket.flush();
    await Future<void>.delayed(const Duration(milliseconds: 100));
    socket.destroy();

    await expectLater(
      sawCancel.future.timeout(const Duration(seconds: 3)),
      completes,
    );
    release.complete();
  }, skip: conformance.skipPeerGone);

  test('Given a streamed response and a handler waiting on cancelled, '
      'when the peer hangs up, then cancelled completes', () async {
    final sawCancel = Completer<void>();
    await serve((req) {
      unawaited(req.cancelled.then((_) => sawCancel.complete()));
      final body = Stream<Uint8List>.periodic(
        const Duration(milliseconds: 10),
        (_) => Uint8List(1024),
      );
      return Response.ok(body: Body.fromDataStream(body));
    });

    final socket = await connect();
    socket.write('GET / HTTP/1.1\r\nHost: x\r\n\r\n');
    await socket.flush();
    await socket.first;
    socket.destroy();

    await expectLater(
      sawCancel.future.timeout(const Duration(seconds: 3)),
      completes,
    );
  }, skip: conformance.skipPeerGone);

  test('Given a handler waiting on cancelled, when the peer stays, '
      'then cancelled does not complete and the response arrives', () async {
    var cancelledFired = false;
    await serve((req) async {
      unawaited(req.cancelled.then((_) => cancelledFired = true));
      await Future<void>.delayed(const Duration(milliseconds: 200));
      return Response.ok(body: Body.fromString('done'));
    });

    final response = await http.get(server!.url);

    expect(response.body, 'done');
    expect(cancelledFired, isFalse);
  });

  test('Given a keep-alive connection that was answered, '
      'when the peer closes it, then the server lets it go', () async {
    await serve((req) => Response.ok(body: Body.fromString('ok')));

    final socket = await connect();
    socket.write('GET / HTTP/1.1\r\nHost: x\r\n\r\n');
    await socket.flush();
    await socket.first;
    socket.destroy();

    var info = await server!.connectionsInfo();
    final deadline = Stopwatch()..start();
    while (info.idle + info.active > 0 &&
        deadline.elapsed < const Duration(seconds: 5)) {
      await Future<void>.delayed(const Duration(milliseconds: 20));
      info = await server!.connectionsInfo();
    }
    expect(info.idle + info.active, 0);
  });

  test(
    'Given a handler that never reads cancelled, '
    'when the peer hangs up, then the server serves the next request',
    () async {
      await serve((req) async {
        await Future<void>.delayed(const Duration(milliseconds: 100));
        return Response.ok(body: Body.fromString('ok'));
      });

      final socket = await connect();
      socket.write('GET / HTTP/1.1\r\nHost: x\r\n\r\n');
      await socket.flush();
      socket.destroy();

      final response = await http.get(server!.url);
      expect(response.body, 'ok');
    },
  );
}
