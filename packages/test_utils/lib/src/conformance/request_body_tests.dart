import 'dart:async';
import 'dart:convert';
import 'dart:io' as io;
import 'dart:typed_data';

import 'package:http/http.dart' as http;
import 'package:relic_core/relic_core.dart';
import 'package:test/test.dart';

import 'conformance.dart';

/// The core builds the body a handler gets from the request's headers,
/// the same way on every adapter.
void requestBodyTests(AdapterConformance conformance) {
  RelicServer? server;

  tearDown(() async {
    await server?.close(force: true);
    server = null;
  });

  Future<void> serve(Handler handler) async {
    server = await conformance.serve(handler);
  }

  group('Given the request body', () {
    test('when a GET has no body, then the request is empty', () async {
      await serve(
        (req) => Response.ok(
          body: Body.fromString(
            '${req.isEmpty} ${req.body.contentLength} ${req.body.bodyType}',
          ),
        ),
      );

      final response = await http.get(server!.url);

      expect(response.body, 'true 0 null');
    });

    test('when a POST declares a type with a charset and a parameter, '
        'then the body carries them', () async {
      await serve((req) async {
        final type = req.body.bodyType!;
        final text = await req.readAsString();
        return Response.ok(
          body: Body.fromString(
            '${type.mimeType.primaryType}/${type.mimeType.subType} '
            '${type.encoding?.name} ${type.parameters} $text',
          ),
        );
      });

      final response = await http.post(
        server!.url,
        headers: {'content-type': 'text/plain; charset=utf-8; foo=bar'},
        body: 'hi',
      );

      expect(response.body, 'text/plain utf-8 {foo: bar} hi');
    });

    test('when a POST declares a Content-Type that does not parse, '
        'then the body has no type and still reads', () async {
      await serve((req) async {
        final bytes = await req.body.readAll();
        return Response.ok(
          body: Body.fromString('${req.body.bodyType} ${utf8.decode(bytes)}'),
        );
      });

      // No HTTP client sends such a header, so this one is written by hand.
      final reply = await rawExchange(
        server!.port,
        'POST / HTTP/1.1\r\nHost: x\r\nContent-Type: ;;;\r\n'
        'Content-Length: 2\r\nConnection: close\r\n\r\nhi',
      );

      expect(reply, endsWith('\r\n\r\nnull hi'));
    });

    test('when a POST declares a length over the limit of a read, '
        'then the client receives the answer of the handler.', () async {
      await serve((req) async {
        try {
          await req.read(maxLength: 1024).drain<void>();
          return Response.ok();
        } on MaxBodySizeExceeded {
          return Response.contentTooLarge(body: Body.fromString('too large'));
        }
      });

      // Big enough that the client is still sending when the handler answers.
      final response = await http.post(server!.url, body: Uint8List(16 << 20));

      expect(response.statusCode, 413);
      expect(response.body, 'too large');
    });

    test('when a chunked POST runs over the limit of a read, '
        'then the client receives the answer of the handler.', () async {
      await serve((req) async {
        try {
          await req.read(maxLength: 1024).drain<void>();
          return Response.ok();
        } on MaxBodySizeExceeded {
          return Response.contentTooLarge(body: Body.fromString('too large'));
        }
      });

      final request = http.StreamedRequest('POST', server!.url);
      for (var i = 0; i < 256; i++) {
        request.sink.add(Uint8List(64 << 10));
      }
      unawaited(request.sink.close());
      final response = await http.Response.fromStream(await request.send());

      expect(response.statusCode, 413);
      expect(response.body, 'too large');
    });

    test('when the handler answers without reading a large body, '
        'then the next request goes on the same connection.', () async {
      await serve((req) => Response.ok());
      final client = io.HttpClient()..maxConnectionsPerHost = 1;
      addTearDown(client.close);

      Future<int> localPortOfPost(int size) async {
        final request = await client.postUrl(server!.url);
        request.add(Uint8List(size));
        final response = await request.close();
        final port = response.connectionInfo!.localPort;
        await response.drain<void>();
        return port;
      }

      final first = await localPortOfPost(8 << 20);
      final second = await localPortOfPost(1);

      expect(second, first);
    });

    test('when the handler pipes it into the response, '
        'then the client receives it echoed', () async {
      await serve(
        (req) => Response.ok(body: Body.fromDataStream(req.body.read())),
      );

      // No length, so the request goes out chunked and streams to the
      // handler on every adapter, whatever its inline limit.
      final request = http.StreamedRequest('POST', server!.url);
      request.sink.add(utf8.encode('hello'));
      request.sink.add(utf8.encode(' world'));
      unawaited(request.sink.close());
      final response = await http.Response.fromStream(
        await request.send(),
      ).timeout(const Duration(seconds: 5));

      expect(response.statusCode, 200);
      expect(response.body, 'hello world');
    });
  });
}
