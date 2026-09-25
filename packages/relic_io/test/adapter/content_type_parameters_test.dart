import 'dart:io';
import 'dart:typed_data';

import 'package:relic_core/relic_core.dart';
import 'package:relic_io/relic_io.dart';
import 'package:test/test.dart';

import '../util/test_util.dart';

void main() {
  late RelicServer server;
  late HttpClient client;

  setUp(() => client = HttpClient());

  tearDown(() async {
    client.close(force: true);
    await server.close();
  });

  test(
    'Given a static file, '
    'when two byte ranges are requested over HTTP, '
    'then the Content-Type boundary is the one that delimits the body.',
    () async {
      final directory = await Directory.systemTemp.createTemp('relic_ranges_');
      addTearDown(() => directory.delete(recursive: true));
      await File('${directory.path}/file.txt').writeAsString('0123456789');
      server = await testServe(
        StaticHandler.directory(
          directory,
          cacheControl: (_, _) => null,
        ).asHandler,
      );

      final request = await client.getUrl(server.url.resolve('/file.txt'));
      request.headers.set(HttpHeaders.rangeHeader, 'bytes=0-0,2-3');
      final response = await request.close();
      final body = await response
          .transform(const SystemEncoding().decoder)
          .join();
      final boundary = response.headers.contentType?.parameters['boundary'];

      expect(boundary, isNotNull);
      expect(body, endsWith('--$boundary--\r\n'));
    },
  );

  test('Given a request with a boundary in its Content-Type, '
      'when the handler reads the request body type, '
      'then the boundary is a body type parameter.', () async {
    String? boundary;
    server = await testServe((final req) async {
      boundary = req.body.bodyType?.parameter('boundary');
      await req.read().drain<void>();
      return Response.ok();
    });

    final request = await client.postUrl(server.url);
    request.headers.set(
      HttpHeaders.contentTypeHeader,
      'multipart/form-data; boundary=abc123',
    );
    request.add(Uint8List.fromList('--abc123--\r\n'.codeUnits));
    await (await request.close()).drain<void>();

    expect(boundary, 'abc123');
  });

  test(
    'Given a request whose Content-Type has a parameter name that is not a token, '
    'when the handler echoes the request body, '
    'then the response succeeds without that parameter.',
    () async {
      server = await testServe((final req) => Response.ok(body: req.body));

      final request = await client.postUrl(server.url);
      request.headers.set(HttpHeaders.contentTypeHeader, 'text/plain; a@b=c');
      request.add(Uint8List.fromList('hi'.codeUnits));
      final response = await request.close();
      await response.drain<void>();

      expect(response.statusCode, 200);
      expect(response.headers.contentType?.parameters, isNot(contains('a@b')));
    },
  );

  test('Given a response body with a boundary parameter, '
      'when the response is written, '
      'then the client receives the boundary in Content-Type.', () async {
    server = await testServe(
      (final req) async => Response.ok(
        body: Body.fromData(
          Uint8List.fromList('--abc123--\r\n'.codeUnits),
          mimeType: const MimeType('multipart', 'mixed'),
          parameters: const {'boundary': 'abc123'},
        ),
      ),
    );

    final response = await (await client.getUrl(server.url)).close();
    await response.drain<void>();

    expect(response.headers.contentType?.parameters['boundary'], 'abc123');
  });
}
