import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart' as parser;
import 'package:relic_core/relic_core.dart';
import 'package:test/test.dart';
import 'package:web_socket/web_socket.dart';

import '../test_utils_base.dart';
import 'conformance.dart';

void serveTests(AdapterConformance conformance) {
  RelicServer? server;
  int serverPort() => server!.url.port;

  Future<void> scheduleServer(Handler handler) async {
    assert(server == null);
    server = await conformance.serve(handler);
  }

  Future<http.Response> get({
    Map<String, String>? headers,
    String path = '',
  }) async {
    final request = http.Request(
      Method.get.value,
      Uri.http('localhost:${serverPort()}', path),
    );
    if (headers != null) request.headers.addAll(headers);
    final response = await request.send();
    return await http.Response.fromStream(
      response,
    ).timeout(const Duration(seconds: 1));
  }

  Future<http.StreamedResponse> post({
    Map<String, String>? headers,
    String? body,
  }) {
    final request = http.Request(
      Method.post.value,
      Uri.http('localhost:${serverPort()}', ''),
    );
    if (headers != null) request.headers.addAll(headers);
    if (body != null) request.body = body;
    return request.send();
  }

  tearDown(() async {
    final s = server;
    if (s != null) {
      try {
        await s.close().timeout(const Duration(seconds: 5));
      } catch (e) {
        await s.close();
      } finally {
        server = null;
      }
    }
  });

  test('Given a sync handler, when a request is made, '
      'then the client receives its value', () async {
    await scheduleServer(syncHandler);

    final response = await get();
    expect(response.statusCode, HttpStatus.ok);
    expect(response.body, 'Hello from /');
  });

  test('Given an async handler, when a request is made, '
      'then the client receives its value', () async {
    await scheduleServer(asyncHandler);

    final response = await get();
    expect(response.statusCode, HttpStatus.ok);
    expect(response.body, 'Hello from /');
  });

  test('Given a handler that throws, when a request is made, '
      'then the client receives a 500', () async {
    await scheduleServer((request) {
      throw UnsupportedError('test');
    });

    final response = await get();
    expect(response.statusCode, HttpStatus.internalServerError);
    expect(response.body, 'Internal Server Error');
  });

  test('Given a handler that fails asynchronously, when a request is made, '
      'then the client receives a 500', () async {
    await scheduleServer((request) {
      return Future.error('test');
    });

    final response = await get();
    expect(response.statusCode, HttpStatus.internalServerError);
    expect(response.body, 'Internal Server Error');
  });

  test('Given a request with a path and query, when it is served, '
      'then the request is populated correctly', () async {
    late Uri uri;

    await scheduleServer((req) {
      expect(req.method, Method.get);

      expect(req.url, uri);

      expect(req.url.path, '/foo/bar');
      expect(req.url.pathSegments, ['foo', 'bar']);
      expect(req.protocol, HttpProtocol.http11);
      expect(req.url.query, 'qs=value');

      return syncHandler(req);
    });

    uri = Uri.http('localhost:${serverPort()}', '/foo/bar', {'qs': 'value'});
    final response = await http.get(uri);

    expect(response.statusCode, HttpStatus.ok);
    expect(response.body, 'Hello from /foo/bar');
  });

  test('Given a path with a colon in its first segment, when it is served, '
      'then the request keeps it', () async {
    await scheduleServer(syncHandler);

    final response = await get(path: 'user:42');
    expect(response.statusCode, HttpStatus.ok);
    expect(response.body, 'Hello from /user:42');
  });

  test('Given custom response headers, when a request is made, '
      'then the client receives them', () async {
    await scheduleServer(
      createSyncHandler(
        body: Body.fromString('Hello from /'),
        headers: Headers.fromMap({
          'test-header': ['test-value'],
          'test-list': ['a', 'b', 'c'],
        }),
      ),
    );

    final response = await get();
    expect(response.statusCode, HttpStatus.ok);
    expect(response.headers['test-header'], 'test-value');
    expect(response.body, 'Hello from /');
  });

  test('Given a custom status code, when a request is made, '
      'then the client receives it', () async {
    await scheduleServer(
      createSyncHandler(statusCode: 299, body: Body.fromString('Hello from /')),
    );

    final response = await get();
    expect(response.statusCode, 299);
    expect(response.body, 'Hello from /');
  });

  test('Given custom request headers, when a request is made, '
      'then the handler receives them', () async {
    const multi = HeaderAccessor<List<String>>(
      'multi-header',
      HeaderCodec(parseStringList, encodeStringList),
    );
    await scheduleServer((req) {
      expect(req.headers, containsPair('custom-header', ['client value']));

      // A multi-value header arrives as one field and is split by the
      // typed accessor, whatever the adapter did with it on the way in.
      expect(req.headers, containsPair('multi-header', ['foo,bar,baz']));

      expect(multi[req.headers].value, ['foo', 'bar', 'baz']);

      return syncHandler(req);
    });

    final headers = {
      'custom-header': 'client value',
      'multi-header': 'foo,bar,baz',
    };

    final response = await get(headers: headers);
    expect(response.statusCode, HttpStatus.ok);
    expect(response.body, 'Hello from /');
  });

  test('Given a POST with empty content, when it is served, '
      'then the body reads as empty', () async {
    await scheduleServer((req) async {
      expect(req.mimeType, isNull);
      expect(req.encoding, isNull);
      expect(req.method, Method.post);
      expect(req.body.contentLength, isNull);

      final body = await req.readAsString();
      expect(body, '');
      return syncHandler(req);
    });

    final response = await post();
    expect(response.statusCode, HttpStatus.ok);
    expect(response.stream.bytesToString(), completion('Hello from /'));
  });

  test('Given a POST with content, when it is served, '
      'then the body and its type are readable', () async {
    await scheduleServer((req) async {
      expect(req.mimeType?.primaryType, 'text');
      expect(req.mimeType?.subType, 'plain');
      expect(req.encoding, utf8);
      expect(req.method, Method.post);
      expect(req.body.contentLength, 9);

      final body = await req.readAsString();
      expect(body, 'test body');

      return syncHandler(req);
    });

    final response = await post(body: 'test body');
    expect(response.statusCode, HttpStatus.ok);
    expect(response.stream.bytesToString(), completion('Hello from /'));
  });

  test('Given a handler that hijacks, when a request is made, '
      'then the raw bytes written reach the client', () async {
    await scheduleServer((req) {
      expect(req.method, Method.post);

      return Hijack(
        expectAsync1((channel) {
          expect(channel.stream.first, completion(equals('Hello'.codeUnits)));

          channel.sink.add(
            utf8.encode(
              'HTTP/1.1 404 Not Found\r\n'
              'date: Mon, 23 May 2005 22:38:34 GMT\r\n'
              'Content-Length: 13\r\n'
              '\r\n'
              'Hello, world!',
            ),
          );
          channel.sink.close();
        }),
      );
    });

    final response = await post(body: 'Hello');
    expect(response.statusCode, HttpStatus.notFound);
    expect(response.headers['date'], 'Mon, 23 May 2005 22:38:34 GMT');
    expect(
      response.stream.bytesToString(),
      completion(equals('Hello, world!')),
    );
  }, skip: conformance.skipHijack);

  test('Given a handler that upgrades, when a client connects, '
      'then messages flow both ways', () async {
    await scheduleServer((req) {
      return WebSocketUpgrade(
        expectAsync1((serverSocket) async {
          await for (final e in serverSocket.events) {
            expect(e, TextDataReceived('Hello'));
            serverSocket.sendText('Hello, world!');
            await serverSocket.close();
          }
        }),
      );
    });

    final ws = await WebSocket.connect(
      Uri.parse('ws://localhost:${serverPort()}'),
    );
    ws.sendText('Hello');
    expect(ws.events.first, completion(TextDataReceived('Hello, world!')));
  }, skip: conformance.skipWebSocket);

  test('Given a handler that leaks an async error, '
      'when served in a guarded zone, '
      'then the error reaches that zone', () async {
    await runZonedGuarded(
      () async {
        final server = await conformance.serve((req) {
          Future(() => throw StateError('oh no'));
          return syncHandler(req);
        });

        final response = await http.get(server.url);
        expect(response.statusCode, HttpStatus.ok);
        expect(response.body, 'Hello from /');
        await server.close();
      },
      expectAsync2((error, stack) {
        expect(error, isOhNoStateError);
      }),
    );
  });

  test('Given a handler that leaks an async error, '
      'when served in the root zone, '
      'then the error does not escape to the root zone', () async {
    final response = await Zone.root.run(() async {
      final server = await conformance.serve((request) {
        Future(() => throw StateError('oh no'));
        return syncHandler(request);
      });

      try {
        return await http.get(server.url);
      } finally {
        await server.close();
      }
    });

    expect(response.statusCode, HttpStatus.ok);
    expect(response.body, 'Hello from /');
  });

  test('Given a bad Host header, when the request is made, '
      'then the client receives a 400', () async {
    await scheduleServer(syncHandler);

    final socket = await Socket.connect('localhost', serverPort());

    try {
      socket.write('GET / HTTP/1.1\r\n');
      socket.write('Host: ^^super bad !@#host\r\n');
      socket.write('\r\n');
    } finally {
      await socket.close();
    }

    expect(await utf8.decodeStream(socket), contains('400 Bad Request'));
  });

  test('Given a request target with a fragment, when the request is made, '
      'then the client receives a 400', () async {
    await scheduleServer(syncHandler);
    final socket = await Socket.connect('localhost', serverPort());

    try {
      socket.write('GET /#/ HTTP/1.1\r\n');
      socket.write('Host: localhost\r\n');
      socket.write('\r\n');
    } finally {
      await socket.close();
    }

    expect(await utf8.decodeStream(socket), contains('400 Bad Request'));
  });

  group('Given a response without a Date header', () {
    test('when it is sent, then a current Date is added', () async {
      await scheduleServer(syncHandler);

      // HTTP dates have second granularity and the request takes less than
      // a second, so start the window one second early.
      final beforeRequest = DateTime.now().subtract(const Duration(seconds: 1));

      final response = await get();
      expect(response.headers, contains('date'));
      final responseDate = parser.parseHttpDate(response.headers['date']!);

      expect(responseDate.isAfter(beforeRequest), isTrue);
      expect(responseDate.isBefore(DateTime.now()), isTrue);
    });
  });

  test('Given a response with its own Date header, when it is sent, '
      'then that Date is kept', () async {
    final date = DateTime.utc(1981, 6, 5);
    await scheduleServer(
      createSyncHandler(
        body: Body.fromString('test'),
        headers: Headers.build((mh) => mh.date = date),
      ),
    );

    final response = await get();
    expect(response.headers, contains('date'));
    final responseDate = parser.parseHttpDate(response.headers['date']!);
    expect(responseDate, date);
  });

  group('Given the X-Powered-By header', () {
    const poweredBy = 'x-powered-by';

    test('when a plain response is sent, then it is not set', () async {
      await scheduleServer(syncHandler);

      final response = await get();
      expect(response.headers[poweredBy], isNull);
    });

    test('when a handler sets it, then the client receives it', () async {
      await scheduleServer(
        respondWith((request) {
          return Response.ok(
            body: Body.fromString('test'),
            headers: Headers.build((mh) => mh.xPoweredBy = 'myServer'),
          );
        }),
      );

      final response = await get();
      expect(response.headers, containsPair(poweredBy, 'myServer'));
    });
  });

  test(
    'Given a response with a chunked transfer encoding header and an empty body, '
    'when it is sent, '
    'then the transfer encoding header is dropped',
    () async {
      await scheduleServer(
        createSyncHandler(
          body: Body.empty(),
          headers: Headers.build(
            (mh) => mh.transferEncoding = TransferEncodingHeader.encodings([
              TransferEncoding.chunked,
            ]),
          ),
        ),
      );

      final response = await get();
      expect(response.body, isEmpty);
      expect(response.headers['transfer-encoding'], isNull);
    },
  );
}
