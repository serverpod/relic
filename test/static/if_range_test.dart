import 'dart:io';

import 'package:path/path.dart' as p;
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
      'Given an If-Range header with a matching ETag, '
      'when a range request is made, '
      'then a 206 Partial Content response with partial content is returned',
      () async {
    final initialResponse = await makeRequest(handler, '/test_file.txt');
    final etag = initialResponse.headers.etag!.value;
    final headers = Headers.build((final mh) => mh
      ..range = RangeHeader(ranges: [Range(start: 0, end: 4)])
      ..ifRange = IfRangeHeader(etag: ETagHeader(value: etag)));

    final response =
        await makeRequest(handler, '/test_file.txt', headers: headers);

    expect(response.statusCode, HttpStatus.partialContent);
    expect(response.body.contentLength, 5);
    expect(response.readAsString(), completion(fileContent.substring(0, 5)));
  });

  test(
      'Given an If-Range header with a non-matching ETag, '
      'when a range request is made, '
      'then a 200 OK status with full content is returned', () async {
    const nonMatchingEtag = ETagHeader(value: 'non-existent-etag');
    final headers = Headers.build((final mh) => mh
      ..range = RangeHeader(ranges: [Range(end: 4)])
      ..ifRange = IfRangeHeader(etag: nonMatchingEtag));

    final response =
        await makeRequest(handler, '/test_file.txt', headers: headers);

    expect(response.statusCode, HttpStatus.ok);
    expect(response.body.contentLength, fileContent.length);
    expect(response.readAsString(), completion(fileContent));
  });

  test(
      'Given an If-Range header with a matching Last-Modified date, '
      'when a range request is made, '
      'then a 206 Partial Content response with partial content is returned',
      () async {
    final rootPath = p.join(d.sandbox, 'test_file.txt');
    final modified = File(rootPath).statSync().modified.toUtc();
    final headers = Headers.build((final mh) => mh
      ..range = RangeHeader(ranges: [Range(start: 0, end: 4)])
      ..ifRange = IfRangeHeader(lastModified: modified));

    final response =
        await makeRequest(handler, '/test_file.txt', headers: headers);

    expect(response.statusCode, HttpStatus.partialContent);
    expect(response.body.contentLength, 5);
    expect(response.readAsString(), completion(fileContent.substring(0, 5)));
  });

  test(
      'Given an If-Range header with a non-matching (earlier) Last-Modified date, '
      'when a range request is made, '
      'then a 200 OK status with full content is returned', () async {
    final rootPath = p.join(d.sandbox, 'test_file.txt');
    final modified = File(rootPath).statSync().modified.toUtc();
    final earlierModified = modified.subtract(const Duration(days: 1));
    final headers = Headers.build((final mh) => mh
      ..range = RangeHeader(ranges: [Range(start: 0, end: 4)])
      ..ifRange = IfRangeHeader(lastModified: earlierModified));

    final response =
        await makeRequest(handler, '/test_file.txt', headers: headers);

    expect(response.statusCode, HttpStatus.ok);
    expect(response.body.contentLength, fileContent.length);
    expect(response.readAsString(), completion(fileContent));
  });
}
