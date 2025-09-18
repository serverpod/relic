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
    handler = createStaticHandler(cacheControl: null, d.sandbox);
  });

  test(
      'Given an If-None-Match header with a matching ETag, '
      'when a request is made for the file, '
      'then a 304 Not Modified status is returned with no body', () async {
    final initialResponse = await makeRequest(handler, '/test_file.txt');
    final etag = initialResponse.headers.etag!.value;
    final headers =
        Headers.build((final mh) => mh.ifNoneMatch = IfNoneMatchHeader.etags(
              [ETagHeader(value: etag)],
            ));

    final response =
        await makeRequest(handler, '/test_file.txt', headers: headers);

    expect(response.statusCode, HttpStatus.notModified);
    expect(response.body.contentLength, 0);
    expect(await response.readAsString(), isEmpty);
  });

  test(
      'Given an If-None-Match header with a non-matching ETag, '
      'when a request is made for the file, '
      'then a 200 OK status is returned with the full body', () async {
    const nonMatchingEtag = ETagHeader(value: 'non-existent-etag');
    final headers =
        Headers.build((final mh) => mh.ifNoneMatch = IfNoneMatchHeader.etags(
              [nonMatchingEtag],
            ));

    final response =
        await makeRequest(handler, '/test_file.txt', headers: headers);

    expect(response.statusCode, HttpStatus.ok);
    expect(response.body.contentLength, fileContent.length);
    expect(response.readAsString(), completion(fileContent));
  });

  test(
      'Given an If-None-Match header with multiple ETags including a matching one, '
      'when a request is made for the file, '
      'then a 304 Not Modified status is returned with no body', () async {
    final initialResponse = await makeRequest(handler, '/test_file.txt');
    final etag = initialResponse.headers.etag!.value;
    final headers =
        Headers.build((final mh) => mh.ifNoneMatch = IfNoneMatchHeader.etags([
              const ETagHeader(value: 'first-non-matching'),
              ETagHeader(value: etag), // correct value
              const ETagHeader(value: 'second-non-matching'),
            ]));

    final response =
        await makeRequest(handler, '/test_file.txt', headers: headers);

    expect(response.statusCode, HttpStatus.notModified);
    expect(response.body.contentLength, 0);
    expect(await response.readAsString(), isEmpty);
  });

  test(
      'Given an If-None-Match header with wildcard, '
      'when a request is made for the file, '
      'then a 304 Not Modified status is returned with no body', () async {
    final headers = Headers.build(
      (final mh) => mh.ifNoneMatch = const IfNoneMatchHeader.wildcard(),
    );
    final response =
        await makeRequest(handler, '/test_file.txt', headers: headers);

    expect(response.statusCode, HttpStatus.notModified);
    expect(response.body.contentLength, 0);
    expect(await response.readAsString(), isEmpty);
  });
}
