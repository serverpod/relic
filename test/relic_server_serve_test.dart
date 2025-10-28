import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:async/async.dart';
import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart' as parser;
import 'package:relic/relic.dart';
import 'package:relic/src/headers/codecs/common_types_codecs.dart';
import 'package:test/test.dart';
import 'package:web_socket/web_socket.dart';

import 'headers/headers_test_utils.dart';
import 'ssl/ssl_certs.dart';
import 'util/test_util.dart';

void main() {
  tearDown(() async {
    final server = _server;
    if (server != null) {
      try {
        await server.close().timeout(const Duration(seconds: 5));
      } catch (e) {
        await server.close();
      } finally {
        _server = null;
      }
    }
  });

  test('sync handler returns a value to the client', () async {
    await _scheduleServer(syncHandler);

    final response = await _get();
    expect(response.statusCode, HttpStatus.ok);
    expect(response.body, 'Hello from /');
  });

  test('async handler returns a value to the client', () async {
    await _scheduleServer(asyncHandler);

    final response = await _get();
    expect(response.statusCode, HttpStatus.ok);
    expect(response.body, 'Hello from /');
  });

  test('thrown error leads to a 500', () async {
    await _scheduleServer((final request) {
      throw UnsupportedError('test');
    });

    final response = await _get();
    expect(response.statusCode, HttpStatus.internalServerError);
    expect(response.body, 'Internal Server Error');
  });

  test('async error leads to a 500', () async {
    await _scheduleServer((final request) {
      return Future.error('test');
    });

    final response = await _get();
    expect(response.statusCode, HttpStatus.internalServerError);
    expect(response.body, 'Internal Server Error');
  });

  test('Request is populated correctly', () async {
    late Uri uri;

    await _scheduleServer((final ctx) {
      final request = ctx.request;
      expect(request.method, Method.get);

      expect(request.requestedUri, uri);

      expect(request.url.path, 'foo/bar');
      expect(request.url.pathSegments, ['foo', 'bar']);
      expect(request.protocolVersion, '1.1');
      expect(request.url.query, 'qs=value');
      expect(request.handlerPath, '/');

      return syncHandler(ctx);
    });

    uri = Uri.http('localhost:$_serverPort', '/foo/bar', {'qs': 'value'});
    final response = await http.get(uri);

    expect(response.statusCode, HttpStatus.ok);
    expect(response.body, 'Hello from /foo/bar');
  });

  test('Request can handle colon in first path segment', () async {
    await _scheduleServer(syncHandler);

    final response = await _get(path: 'user:42');
    expect(response.statusCode, HttpStatus.ok);
    expect(response.body, 'Hello from /user:42');
  });

  test('custom response headers are received by the client', () async {
    await _scheduleServer(
      createSyncHandler(
        body: Body.fromString('Hello from /'),
        headers: Headers.fromMap({
          'test-header': ['test-value'],
          'test-list': ['a', 'b', 'c'],
        }),
      ),
    );

    final response = await _get();
    expect(response.statusCode, HttpStatus.ok);
    expect(response.headers['test-header'], 'test-value');
    expect(response.body, 'Hello from /');
  });

  test('custom status code is received by the client', () async {
    await _scheduleServer(
      (createSyncHandler(
        statusCode: 299,
        body: Body.fromString('Hello from /'),
      )),
    );

    final response = await _get();
    expect(response.statusCode, 299);
    expect(response.body, 'Hello from /');
  });

  test('custom request headers are received by the handler', () async {
    const multi = HeaderAccessor<List<String>>(
      'multi-header',
      HeaderCodec(parseStringList, encodeStringList),
    );
    await _scheduleServer((final ctx) {
      final request = ctx.request;
      expect(request.headers, containsPair('custom-header', ['client value']));

      // dart:io HttpServer splits multi-value headers into an array
      // validate that they are combined correctly
      expect(request.headers, containsPair('multi-header', ['foo,bar,baz']));

      expect(multi[request.headers].value, ['foo', 'bar', 'baz']);

      return syncHandler(ctx);
    });

    final headers = {
      'custom-header': 'client value',
      'multi-header': 'foo,bar,baz',
    };

    final response = await _get(headers: headers);
    expect(response.statusCode, HttpStatus.ok);
    expect(response.body, 'Hello from /');
  });

  test('post with empty content', () async {
    await _scheduleServer((final ctx) async {
      final request = ctx.request;
      expect(request.mimeType, isNull);
      expect(request.encoding, isNull);
      expect(request.method, Method.post);
      expect(request.body.contentLength, isNull);

      final body = await request.readAsString();
      expect(body, '');
      return syncHandler(ctx);
    });

    final response = await _post();
    expect(response.statusCode, HttpStatus.ok);
    expect(response.stream.bytesToString(), completion('Hello from /'));
  });

  test('post with request content', () async {
    await _scheduleServer((final ctx) async {
      final request = ctx.request;

      expect(request.mimeType?.primaryType, 'text');
      expect(request.mimeType?.subType, 'plain');
      expect(request.encoding, utf8);
      expect(request.method, Method.post);
      expect(request.body.contentLength, 9);

      final body = await request.readAsString();
      expect(body, 'test body');

      return syncHandler(ctx);
    });

    final response = await _post(body: 'test body');
    expect(response.statusCode, HttpStatus.ok);
    expect(response.stream.bytesToString(), completion('Hello from /'));
  });

  test('supports request hijacking', () async {
    await _scheduleServer((final ctx) {
      final request = ctx.request;

      expect(request.method, Method.post);

      return ctx.hijack(
        expectAsync1((final channel) {
          expect(channel.stream.first, completion(equals('Hello'.codeUnits)));

          channel.sink.add(
            'HTTP/1.1 404 Not Found\r\n'
                    'date: Mon, 23 May 2005 22:38:34 GMT\r\n'
                    'Content-Length: 13\r\n'
                    '\r\n'
                    'Hello, world!'
                .codeUnits,
          );
          channel.sink.close();
        }),
      );
    });

    final response = await _post(body: 'Hello');
    expect(response.statusCode, HttpStatus.notFound);
    expect(response.headers['date'], 'Mon, 23 May 2005 22:38:34 GMT');
    expect(
      response.stream.bytesToString(),
      completion(equals('Hello, world!')),
    );
  });

  test('supports web socket connetions', () async {
    await _scheduleServer((final ctx) {
      return ctx.connect(
        expectAsync1((final serverSocket) async {
          await for (final e in serverSocket.events) {
            expect(e, TextDataReceived('Hello'));
            serverSocket.sendText('Hello, world!');
            await serverSocket.close();
          }
        }),
      );
    });

    final ws = await WebSocket.connect(
      Uri.parse('ws://localhost:$_serverPort'),
    );
    ws.sendText('Hello');
    expect(ws.events.first, completion(TextDataReceived('Hello, world!')));
  });

  test('passes asynchronous exceptions to the parent error zone', () async {
    await runZonedGuarded(
      () async {
        final server = await testServe((final ctx) {
          Future(() => throw StateError('oh no'));
          return syncHandler(ctx);
        });

        final response = await http.get(server.url);
        expect(response.statusCode, HttpStatus.ok);
        expect(response.body, 'Hello from /');
        await server.close();
      },
      expectAsync2((final error, final stack) {
        expect(error, isOhNoStateError);
      }),
    );
  });

  test("doesn't pass asynchronous exceptions to the root error zone", () async {
    final response = await Zone.root.run(() async {
      final server = await testServe((final request) {
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

  test('a bad HTTP host request results in a 400 response', () async {
    await _scheduleServer(syncHandler);

    final socket = await Socket.connect('localhost', _serverPort);

    try {
      socket.write('GET / HTTP/1.1\r\n');
      socket.write('Host: ^^super bad !@#host\r\n');
      socket.write('\r\n');
    } finally {
      await socket.close();
    }

    expect(await utf8.decodeStream(socket), contains('400 Bad Request'));
  });

  test('a bad HTTP URL request results in a 400 response', () async {
    await _scheduleServer(syncHandler);
    final socket = await Socket.connect('localhost', _serverPort);

    try {
      socket.write('GET /#/ HTTP/1.1\r\n');
      socket.write('Host: localhost\r\n');
      socket.write('\r\n');
    } finally {
      await socket.close();
    }

    expect(await utf8.decodeStream(socket), contains('400 Bad Request'));
  });

  group('date header', () {
    test('is sent by default', () async {
      await _scheduleServer(syncHandler);

      // Update beforeRequest to be one second earlier. HTTP dates only have
      // second-level granularity and the request will likely take less than a
      // second.
      final beforeRequest = DateTime.now().subtract(const Duration(seconds: 1));

      final response = await _get();
      expect(response.headers, contains('date'));
      final responseDate = parser.parseHttpDate(response.headers['date']!);

      expect(responseDate.isAfter(beforeRequest), isTrue);
      expect(responseDate.isBefore(DateTime.now()), isTrue);
    });

    test('defers to header in response', () async {
      final date = DateTime.utc(1981, 6, 5);
      await _scheduleServer(
        createSyncHandler(
          body: Body.fromString('test'),
          headers: Headers.build((final mh) => mh.date = date),
        ),
      );

      final response = await _get();
      expect(response.headers, contains('date'));
      final responseDate = parser.parseHttpDate(response.headers['date']!);
      expect(responseDate, date);
    });
  });

  group('X-Powered-By header', () {
    const poweredBy = 'x-powered-by';
    test('is not automatically set', () async {
      await _scheduleServer(syncHandler);

      final response = await _get();
      expect(response.headers[poweredBy], isNull);
    });

    test('can be set manually in response headers', () async {
      await _scheduleServer(
        respondWith((final request) {
          return Response.ok(
            body: Body.fromString('test'),
            headers: Headers.build((final mh) => mh.xPoweredBy = 'myServer'),
          );
        }),
      );

      final response = await _get();
      expect(response.headers, containsPair(poweredBy, 'myServer'));
    });

    test('is not set by default at server level', () async {
      _server = await testServe(syncHandler);
      final response = await _get();
      expect(response.headers[poweredBy], isNull);
    });

    test('preserves manually set header in response', () async {
      _server = await testServe(
        createSyncHandler(
          headers: Headers.build((final mh) => mh.xPoweredBy = 'myServer'),
        ),
      );

      final response = await _get();
      expect(response.headers, containsPair(poweredBy, 'myServer'));
    });
  });

  test(
    'Given a response with a chunked transfer encoding header and an empty body '
    'when applying headers '
    'then the chunked transfer encoding header is removed from the response',
    () async {
      await _scheduleServer(
        createSyncHandler(
          body: Body.empty(),
          headers: Headers.build(
            (final mh) =>
                mh.transferEncoding = TransferEncodingHeader(
                  encodings: [TransferEncoding.chunked],
                ),
          ),
        ),
      );

      final response = await _get();
      expect(response.body, isEmpty);
      expect(response.headers['transfer-encoding'], isNull);
    },
  );

  test(
    'respects the "buffer_output" context parameter',
    () async {
      final controller = StreamController<String>();
      await _scheduleServer(
        respondWith((final request) {
          controller.add('Hello, ');

          return Response.ok(
            body: Body.fromDataStream(
              utf8.encoder
                  .bind(controller.stream)
                  .map((final list) => Uint8List.fromList(list)),
            ),
            context: {'buffer_output': false},
          );
        }),
      );

      final request = http.Request(
        Method.get.value,
        Uri.http('localhost:$_serverPort', ''),
      );

      final response = await request.send();
      final stream = StreamQueue(utf8.decoder.bind(response.stream));

      var data = await stream.next;
      expect(data, equals('Hello, '));
      controller.add('world!');

      data = await stream.next;
      expect(data, equals('world!'));
      await controller.close();
      expect(stream.hasNext, completion(isFalse));
    },
    skip: 'TODO: Find another way to probagate buffer_output',
  );

  group('ssl tests', () {
    final securityContext =
        SecurityContext()
          ..setTrustedCertificatesBytes(certChainBytes)
          ..useCertificateChainBytes(certChainBytes)
          ..usePrivateKeyBytes(certKeyBytes, password: 'dartdart');

    final sslClient = HttpClient(context: securityContext);

    Future<HttpClientRequest> scheduleSecureGet() =>
        sslClient.getUrl(_server!.url.replace(scheme: 'https'));

    test('secure sync handler returns a value to the client', () async {
      await _scheduleServer(syncHandler, securityContext: securityContext);

      final req = await scheduleSecureGet();

      final response = await req.close();
      expect(response.statusCode, HttpStatus.ok);
      expect(
        await response.cast<List<int>>().transform(utf8.decoder).single,
        'Hello from /',
      );
    });

    test('secure async handler returns a value to the client', () async {
      await _scheduleServer(asyncHandler, securityContext: securityContext);

      final req = await scheduleSecureGet();
      final response = await req.close();
      expect(response.statusCode, HttpStatus.ok);
      expect(
        await response.cast<List<int>>().transform(utf8.decoder).single,
        'Hello from /',
      );
    });
  });
}

int get _serverPort => _server!.url.port;

RelicServer? _server;

Future<void> _scheduleServer(
  final Handler handler, {
  final SecurityContext? securityContext,
}) async {
  assert(_server == null);
  _server = await testServe(handler, context: securityContext);
}

Future<http.Response> _get({
  final Map<String, String>? headers,
  final String path = '',
}) async {
  final request = http.Request(
    Method.get.value,
    Uri.http('localhost:$_serverPort', path),
  );

  if (headers != null) request.headers.addAll(headers);

  final response = await request.send();
  return await http.Response.fromStream(
    response,
  ).timeout(const Duration(seconds: 1));
}

Future<http.StreamedResponse> _post({
  final Map<String, String>? headers,
  final String? body,
}) {
  final request = http.Request(
    Method.post.value,
    Uri.http('localhost:$_serverPort', ''),
  );

  if (headers != null) request.headers.addAll(headers);
  if (body != null) request.body = body;

  return request.send();
}
