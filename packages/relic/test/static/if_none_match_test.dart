import 'dart:io';

import 'package:relic/relic.dart';
import 'package:test/test.dart';
import 'package:test_descriptor/test_descriptor.dart' as d;

import 'test_util.dart'; // Provides the makeRequest helper

void main() {
  const fileContent = '0123456789ABCDEF'; // 16 bytes
  late Handler handler;

  setUp(() async {
    await d.file('test_file.txt', fileContent).create();
    handler = StaticHandler.directory(
      Directory(d.sandbox),
      cacheControl: (_, _) => null,
    ).asHandler;
  });

  test('Given an If-None-Match header with a matching ETag, '
      'when a request is made for the file, '
      'then a 304 Not Modified status is returned with no body', () async {
    final initialResponse = await makeRequest(handler, '/test_file.txt');
    final etag = initialResponse.headers.etag!.value;
    final headers = Headers.build(
      (final mh) =>
          mh.ifNoneMatch = IfNoneMatchHeader.etags([ETagHeader(value: etag)]),
    );

    final response = await makeRequest(
      handler,
      '/test_file.txt',
      headers: headers,
    );

    expect(response.statusCode, HttpStatus.notModified);
    expect(response.body.contentLength, 0);
    expect(await response.readAsString(), isEmpty);
  });

  test('Given an If-None-Match header with a non-matching ETag, '
      'when a request is made for the file, '
      'then a 200 OK status is returned with the full body', () async {
    const nonMatchingEtag = ETagHeader(value: 'non-existent-etag');
    final headers = Headers.build(
      (final mh) => mh.ifNoneMatch = IfNoneMatchHeader.etags([nonMatchingEtag]),
    );

    final response = await makeRequest(
      handler,
      '/test_file.txt',
      headers: headers,
    );

    expect(response.statusCode, HttpStatus.ok);
    expect(response.body.contentLength, fileContent.length);
    expect(response.readAsString(), completion(fileContent));
  });

  test(
    'Given an If-None-Match header with multiple ETags including a matching one, '
    'when a request is made for the file, '
    'then a 304 Not Modified status is returned with no body',
    () async {
      final initialResponse = await makeRequest(handler, '/test_file.txt');
      final etag = initialResponse.headers.etag!.value;
      final headers = Headers.build(
        (final mh) => mh.ifNoneMatch = IfNoneMatchHeader.etags([
          const ETagHeader(value: 'first-non-matching'),
          ETagHeader(value: etag), // correct value
          const ETagHeader(value: 'second-non-matching'),
        ]),
      );

      final response = await makeRequest(
        handler,
        '/test_file.txt',
        headers: headers,
      );

      expect(response.statusCode, HttpStatus.notModified);
      expect(response.body.contentLength, 0);
      expect(await response.readAsString(), isEmpty);
    },
  );

  test(
    'Given an If-None-Match header with an original ETag that no longer match, '
    'when a request is made for the file, '
    'then a 200 OK status is returned with the full body',
    () async {
      await d.file('changing', 'before').create();

      final firstResponse = await makeRequest(handler, '/changing');
      expect(firstResponse.statusCode, 200);
      expect(await firstResponse.readAsString(), 'before');

      final etag = firstResponse.headers.etag!;

      final secondResponse = await makeRequest(
        handler,
        '/changing',
        headers: Headers.build(
          (final mh) => mh.ifNoneMatch = IfNoneMatchHeader.etags([etag]),
        ),
      );

      expect(secondResponse.statusCode, 304);
      expect(await secondResponse.readAsString(), isEmpty);

      await d.file('changing', 'after').create();

      final thirdResponse = await makeRequest(
        handler,
        '/changing',
        headers: Headers.build(
          (final mh) => mh.ifNoneMatch = IfNoneMatchHeader.etags([etag]),
        ),
      );
      expect(thirdResponse.statusCode, 200);
      expect(await thirdResponse.readAsString(), 'after');
    },
  );

  test('Given an If-None-Match header with wildcard, '
      'when a request is made for the file, '
      'then a 304 Not Modified status is returned with no body', () async {
    final headers = Headers.build(
      (final mh) => mh.ifNoneMatch = const IfNoneMatchHeader.wildcard(),
    );
    final response = await makeRequest(
      handler,
      '/test_file.txt',
      headers: headers,
    );

    expect(response.statusCode, HttpStatus.notModified);
    expect(response.body.contentLength, 0);
    expect(await response.readAsString(), isEmpty);
  });
}
