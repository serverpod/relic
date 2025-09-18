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
    await d.dir('test_directory').create();
    handler = createStaticHandler(
        cacheControl: (final _, final __) => null, d.sandbox);
  });

  test(
      'Given a request for a non-existent file, '
      'when the request is made, '
      'then a 404 Not Found status is returned', () async {
    final response = await makeRequest(handler, '/non_existent_file.txt');

    expect(response.statusCode, HttpStatus.notFound);
    expect(response.body.contentLength, greaterThan(0)); // "Not Found" message
    expect(await response.readAsString(), contains('Not Found'));
  });

  test(
      'Given a request for a file in a non-existent directory, '
      'when the request is made, '
      'then a 404 Not Found status is returned', () async {
    final response =
        await makeRequest(handler, '/non_existent_dir/some_file.txt');

    expect(response.statusCode, HttpStatus.notFound);
    expect(response.body.contentLength, greaterThan(0)); // "Not Found" message
    expect(await response.readAsString(), contains('Not Found'));
  });

  test(
      'Given a request for an existing directory, '
      'when the request is made, '
      'then a 404 Not Found status is returned (no directory listings)',
      () async {
    final response = await makeRequest(handler, '/test_directory/');

    expect(response.statusCode, HttpStatus.notFound);
    expect(response.body.contentLength, greaterThan(0)); // "Not Found" message
    expect(await response.readAsString(), contains('Not Found'));
  });

  test(
      'Given a request for an existing directory without trailing slash, '
      'when the request is made, '
      'then a 404 Not Found status is returned (no directory listings)',
      () async {
    final response = await makeRequest(handler, '/test_directory');

    expect(response.statusCode, HttpStatus.notFound);
    expect(response.body.contentLength, greaterThan(0)); // "Not Found" message
    expect(await response.readAsString(), contains('Not Found'));
  });

  test(
      'Given a request with path traversal attempt, '
      'when the request is made, '
      'then a 404 Not Found status is returned', () async {
    final response = await makeRequest(handler, '/../../../etc/passwd');

    expect(response.statusCode, HttpStatus.notFound);
    expect(response.body.contentLength, greaterThan(0)); // "Not Found" message
    expect(await response.readAsString(), contains('Not Found'));
  });

  test(
      'Given a request with URL encoded path traversal attempt, '
      'when the request is made, '
      'then a 404 Not Found status is returned', () async {
    final response =
        await makeRequest(handler, '/%2E%2E%2F%2E%2E%2Fetc%2Fpasswd');

    expect(response.statusCode, HttpStatus.notFound);
    expect(response.body.contentLength, greaterThan(0)); // "Not Found" message
    expect(await response.readAsString(), contains('Not Found'));
  });
}
