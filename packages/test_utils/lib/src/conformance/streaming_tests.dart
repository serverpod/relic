import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:http/http.dart' as http;
import 'package:relic_core/relic_core.dart';
import 'package:test/test.dart';

import 'conformance.dart';

/// A body above the inline limit of every adapter, so it streams to the
/// handler on each of them.
const _bigLength = 3 * 1024 * 1024;

Uint8List _pattern(int length) =>
    Uint8List.fromList(List.generate(length, (i) => i & 0xff));

/// [length] bytes of the pattern in [chunkSize] pieces, with a yield
/// between pieces so the producer never runs ahead of the event loop.
Stream<Uint8List> _patternStream(int length, int chunkSize) async* {
  for (var offset = 0; offset < length; offset += chunkSize) {
    final end = offset + chunkSize > length ? length : offset + chunkSize;
    yield Uint8List.fromList(
      List.generate(end - offset, (i) => (offset + i) & 0xff),
    );
    await Future<void>.delayed(Duration.zero);
  }
}

/// POSTs [bytes] without a Content-Length, so the request goes out
/// chunked and streams to the handler on every adapter, whatever its
/// inline limit.
Future<http.Response> _postChunked(Uri url, Uint8List bytes) async {
  final request = http.StreamedRequest('POST', url);
  const piece = 64 * 1024;
  for (var offset = 0; offset < bytes.length; offset += piece) {
    final end = offset + piece > bytes.length ? bytes.length : offset + piece;
    request.sink.add(bytes.sublist(offset, end));
  }
  unawaited(request.sink.close());
  return http.Response.fromStream(
    await request.send(),
  ).timeout(const Duration(seconds: 10));
}

/// A response body streamed to the peer, and a request body streamed to
/// the handler, flow through the same core code on every adapter.
void streamingTests(AdapterConformance conformance) {
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

  test('Given a streamed response of unknown length, when it is sent, '
      'then the client receives it chunked and complete', () async {
    await serve(
      (req) => Response.ok(
        body: Body.fromDataStream(_patternStream(_bigLength, 17 * 1024)),
      ),
    );

    final response = await http.get(server!.url);

    expect(response.headers['content-length'], isNull);
    expect(response.bodyBytes, _pattern(_bigLength));
  });

  test('Given a streamed response of known length, when it is sent, '
      'then the client receives it with a Content-Length', () async {
    await serve(
      (req) => Response.ok(
        body: Body.fromDataStream(
          _patternStream(_bigLength, 64 * 1024),
          contentLength: _bigLength,
        ),
      ),
    );

    final response = await http.get(server!.url);

    expect(response.headers['content-length'], '$_bigLength');
    expect(response.bodyBytes, _pattern(_bigLength));
  });

  test('Given a streamed response, '
      'when the body stream fails after the head went out, '
      'then the connection drops and no 500 is sent', () async {
    await serve(
      (req) => Response.ok(
        body: Body.fromDataStream(() async* {
          yield Uint8List.fromList([1, 2, 3]);
          await Future<void>.delayed(const Duration(milliseconds: 50));
          throw StateError('the source broke');
        }()),
      ),
    );

    await expectLater(
      http.get(server!.url),
      throwsA(isA<http.ClientException>()),
    );
  });

  test(
    'Given a streamed response whose body was already read, '
    'when it is sent, then the client gets a 500 and not a hanging 200',
    () async {
      await serve((req) {
        final body = Body.fromDataStream(_patternStream(1024, 256));
        body.read();
        return Response.ok(body: body);
      });

      final response = await http
          .get(server!.url)
          .timeout(const Duration(seconds: 5));

      expect(response.statusCode, 500);
    },
  );

  test('Given a streamed response of known length, '
      'when a HEAD is answered with it, then only the head goes out', () async {
    await serve(
      (req) => Response.ok(
        body: Body.fromDataStream(
          _patternStream(_bigLength, 64 * 1024),
          contentLength: _bigLength,
        ),
      ),
    );

    final response = await http.head(server!.url);

    expect(response.statusCode, 200);
    expect(response.headers['content-length'], '$_bigLength');
    expect(response.bodyBytes, isEmpty);
  });

  test(
    'Given a streamed response, when the peer resets mid-body, '
    'then the body stream is cancelled and the next request is served',
    () async {
      final cancelled = Completer<void>();
      await serve((req) {
        if (req.url.path != '/endless') {
          return Response.ok(body: Body.fromString('ok'));
        }
        late final StreamController<Uint8List> source;
        late final Timer pump;
        source = StreamController<Uint8List>(
          onListen: () {
            pump = Timer.periodic(const Duration(milliseconds: 5), (_) {
              if (!source.isPaused) source.add(Uint8List(64 * 1024));
            });
          },
          onCancel: () {
            pump.cancel();
            cancelled.complete();
          },
        );
        return Response.ok(body: Body.fromDataStream(source.stream));
      });

      final socket = await connect();
      socket.write('GET /endless HTTP/1.1\r\nHost: x\r\n\r\n');
      await socket.flush();
      await socket.first;
      socket.destroy();

      await expectLater(
        cancelled.future.timeout(const Duration(seconds: 5)),
        completes,
      );
      final next = await http
          .get(server!.url)
          .timeout(const Duration(seconds: 5));
      expect(next.body, 'ok');
    },
  );

  test('Given a buffered response, '
      'when the peer resets while it is being written, '
      'then the next request is served', () async {
    await serve((req) => Response.ok(body: Body.fromBytes(_pattern(8 << 20))));

    final socket = await connect();
    socket.write('GET / HTTP/1.1\r\nHost: x\r\n\r\n');
    await socket.flush();
    await socket.first;
    socket.destroy();

    final next = await http.get(server!.url);
    expect(next.bodyBytes.length, 8 << 20);
  });

  test('Given a streamed response on a kept-alive connection, '
      'when a second request is made on it, then it is served too', () async {
    await serve(
      (req) => Response.ok(
        body: Body.fromDataStream(_patternStream(100 * 1024, 7 * 1024)),
      ),
    );
    final client = http.Client();
    addTearDown(client.close);

    final first = await client.get(server!.url);
    final second = await client.get(server!.url);

    expect(first.bodyBytes, _pattern(100 * 1024));
    expect(second.bodyBytes, _pattern(100 * 1024));
  });

  test('Given a large request body of known length, '
      'when the handler reads it, then it gets all of it', () async {
    await serve((req) async {
      expect(req.body.contentLength, _bigLength);
      final received = await req.body.readAll();
      expect(received, _pattern(_bigLength));
      return Response.ok(body: Body.fromString('${received.length}'));
    });

    final response = await http.post(server!.url, body: _pattern(_bigLength));

    expect(response.body, '$_bigLength');
  });

  test('Given a large chunked request body, '
      'when the handler reads it, then it gets all of it', () async {
    await serve((req) async {
      expect(req.body.contentLength, isNull);
      final received = await req.body.readAll();
      expect(received, _pattern(_bigLength));
      return Response.ok(body: Body.fromString('${received.length}'));
    });

    final response = await _postChunked(server!.url, _pattern(_bigLength));

    expect(response.body, '$_bigLength');
  });

  test('Given a chunked request body, when the handler reads it, '
      'then it gets the dechunked bytes and no length', () async {
    await serve((req) async {
      expect(req.body.contentLength, isNull);
      final received = await req.readAsString();
      return Response.ok(body: Body.fromString(received));
    });

    final reply = await rawExchange(
      server!.port,
      'POST / HTTP/1.1\r\nHost: x\r\nTransfer-Encoding: chunked\r\n'
      'Connection: close\r\n\r\n'
      '5\r\nhello\r\n6\r\n world\r\n0\r\n\r\n',
    );

    expect(reply, endsWith('hello world'));
  });

  test('Given a large request body of known length, '
      'when the handler answers before reading it, '
      'then the response arrives', () async {
    await serve((req) => Response.ok(body: Body.fromString('early')));

    final response = await http.post(server!.url, body: _pattern(_bigLength));

    expect(response.body, 'early');
    expect(response.headers['connection'], anyOf(isNull, 'close'));
  });

  test('Given a chunked request body, '
      'when the client stops sending mid-body, '
      'then the handler sees the body fail', () async {
    final failed = Completer<Object>();
    await serve((req) async {
      try {
        await req.body.readAll();
        return Response.ok(body: Body.fromString('complete'));
      } catch (e) {
        failed.complete(e);
        return Response.badRequest();
      }
    });

    final socket = await connect();
    socket.write(
      'POST / HTTP/1.1\r\nHost: x\r\nTransfer-Encoding: chunked\r\n\r\n'
      '3e8\r\n',
    );
    socket.add(_pattern(1000));
    await socket.flush();
    await Future<void>.delayed(const Duration(milliseconds: 100));
    socket.destroy();

    await expectLater(
      failed.future.timeout(const Duration(seconds: 5)),
      completion(isA<Object>()),
    );
  });
}
