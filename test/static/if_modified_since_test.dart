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
      'Given an If-Modified-Since header with a matching date, '
      'when a request is made for the file, '
      'then a 304 Not Modified status is returned with no body', () async {
    final initialResponse = await makeRequest(handler, '/test_file.txt');
    final lastModified = initialResponse.headers.lastModified!;

    final headers =
        Headers.build((final mh) => mh.ifModifiedSince = lastModified);

    final response =
        await makeRequest(handler, '/test_file.txt', headers: headers);

    expect(response.statusCode, HttpStatus.notModified);
    expect(response.body.contentLength, 0);
    expect(await response.readAsString(), isEmpty);
  });

  test(
      'Given an If-Modified-Since header with an earlier date, '
      'when a request is made for the file, '
      'then a 200 OK status is returned with the full body', () async {
    final initialResponse = await makeRequest(handler, '/test_file.txt');
    final lastModified = initialResponse.headers.lastModified!;

    // Create an earlier date, simulating the client's cached date
    final earlierDate = lastModified.subtract(const Duration(days: 1));

    final headers =
        Headers.build((final mh) => mh.ifModifiedSince = earlierDate);

    final response =
        await makeRequest(handler, '/test_file.txt', headers: headers);

    expect(response.statusCode, HttpStatus.ok);
    expect(response.body.contentLength, fileContent.length);
    expect(response.readAsString(), completion(fileContent));
  });

  test(
      'Given an If-Modified-Since header with a future date, '
      'when a request is made for the file, '
      'then a 304 Not Modified status is returned with no body', () async {
    final initialResponse = await makeRequest(handler, '/test_file.txt');
    final lastModified = initialResponse.headers.lastModified!;

    // Create a future date, simulating a client with a somehow "newer" cached date
    final futureDate = lastModified.add(const Duration(days: 1));

    final headers =
        Headers.build((final mh) => mh.ifModifiedSince = futureDate);

    final response =
        await makeRequest(handler, '/test_file.txt', headers: headers);

    expect(response.statusCode, HttpStatus.notModified);
    expect(response.body.contentLength, 0);
    expect(await response.readAsString(), isEmpty);
  });
}
