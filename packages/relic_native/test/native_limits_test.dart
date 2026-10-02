import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:http/http.dart' as http;
import 'package:relic_core/relic_core.dart';
import 'package:test/test.dart';

import 'native_test_helpers.dart';

Response _ok(Request _) => Response.ok(body: Body.fromString('ok'));

/// Everything the peer sends until it closes, or null after [limit].
Future<String?> _readUntilClose(
  Socket socket, {
  Duration limit = const Duration(seconds: 5),
}) => utf8
    .decodeStream(socket)
    .then<String?>((s) => s)
    .timeout(limit, onTimeout: () => null);

void main() {
  late RelicServer server;

  tearDown(() => server.close(force: true));

  test('Given an idle timeout, when a connection sends nothing, '
      'then it is closed without a response', () async {
    server = await serveNative(
      _ok,
      idleTimeout: const Duration(milliseconds: 200),
    );
    final socket = await Socket.connect('127.0.0.1', server.port);

    final stopwatch = Stopwatch()..start();
    final received = await _readUntilClose(socket);

    expect(received, '', reason: 'an idle connection gets no status');
    expect(stopwatch.elapsed, lessThan(const Duration(seconds: 3)));
    socket.destroy();
  });

  test('Given a write timeout, '
      'when a client pipelines requests for small responses and reads none, '
      'then the server closes the connection', () async {
    server = await serveNative(
      (_) => Response.ok(body: Body.fromData(Uint8List(48 << 10))),
      writeTimeout: const Duration(milliseconds: 300),
    );
    final socket = await Socket.connect('127.0.0.1', server.port);
    // Never listened to, so the responses back up in the socket buffers
    // until a write of one of them stalls.
    socket.write('GET / HTTP/1.1\r\nHost: x\r\n\r\n' * 400);
    await socket.flush();

    final stopwatch = Stopwatch()..start();
    var info = await server.connectionsInfo();
    while (info.active + info.idle > 0 &&
        stopwatch.elapsed < const Duration(seconds: 5)) {
      await Future<void>.delayed(const Duration(milliseconds: 50));
      info = await server.connectionsInfo();
    }

    expect(info.active + info.idle, 0);
    socket.destroy();
  });

  test('Given a write timeout, when a client stops reading a large response, '
      'then the server closes the connection', () async {
    server = await serveNative(
      (_) => Response.ok(body: Body.fromData(Uint8List(64 << 20))),
      writeTimeout: const Duration(milliseconds: 300),
    );
    final socket = await Socket.connect('127.0.0.1', server.port);
    // Never listened to, so the response backs up in the socket buffers.
    socket.write('GET / HTTP/1.1\r\nHost: x\r\n\r\n');
    await socket.flush();

    final stopwatch = Stopwatch()..start();
    var info = await server.connectionsInfo();
    while (info.active + info.idle > 0 &&
        stopwatch.elapsed < const Duration(seconds: 5)) {
      await Future<void>.delayed(const Duration(milliseconds: 50));
      info = await server.connectionsInfo();
    }

    expect(info.active + info.idle, 0);
    socket.destroy();
  });

  test('Given a header timeout, when a client drips a partial head, '
      'then it gets 408 and the connection closes', () async {
    server = await serveNative(
      _ok,
      headerTimeout: const Duration(milliseconds: 300),
    );
    final socket = await Socket.connect('127.0.0.1', server.port);
    socket.write('GET / HTTP/1.1\r\nHost: x\r\n');
    await socket.flush();
    // A slowloris keeps the head open with a byte now and then.
    final drip = Timer.periodic(const Duration(milliseconds: 50), (_) {
      socket.write('X');
    });

    final received = await _readUntilClose(socket);
    drip.cancel();

    expect(received, startsWith('HTTP/1.1 408'));
    socket.destroy();
  });

  test('Given a body timeout, when a client stops mid-body, '
      'then it gets 408 and the connection closes', () async {
    server = await serveNative(
      _ok,
      bodyTimeout: const Duration(milliseconds: 200),
    );
    final socket = await Socket.connect('127.0.0.1', server.port);
    socket.write('POST / HTTP/1.1\r\nHost: x\r\nContent-Length: 10\r\n\r\nabc');
    await socket.flush();

    final received = await _readUntilClose(socket);

    expect(received, startsWith('HTTP/1.1 408'));
    socket.destroy();
  });

  test('Given a body timeout, when the body arrives in time, '
      'then the request is served', () async {
    server = await serveNative(
      (req) async =>
          Response.ok(body: Body.fromString(await req.readAsString())),
      bodyTimeout: const Duration(seconds: 2),
    );

    final response = await http.post(
      Uri.http('127.0.0.1:${server.port}'),
      body: 'hello',
    );

    expect(response.body, 'hello');
  });

  test('Given a connection cap of one, when two clients request at once, '
      'then the second is served after the first connection ends', () async {
    final first = Completer<void>();
    server = await serveNative((req) async {
      if (req.url.path == '/hold') await first.future;
      return Response.ok(body: Body.fromString(req.url.path));
    }, maxConnections: 1);
    final base = 'http://127.0.0.1:${server.port}';

    final held = http.get(Uri.parse('$base/hold'));
    await Future<void>.delayed(const Duration(milliseconds: 100));
    var secondDone = false;
    final second = http.get(Uri.parse('$base/second')).then((r) {
      secondDone = true;
      return r;
    });
    await Future<void>.delayed(const Duration(milliseconds: 300));

    expect(secondDone, isFalse, reason: 'the cap holds the second back');
    first.complete();
    expect((await held).body, '/hold');
    expect((await second).body, '/second');
  });
}
