import 'dart:io';

import 'package:relic/relic.dart';
import 'package:test/test.dart';
import 'package:test_descriptor/test_descriptor.dart' as d;

import 'test_util.dart'; // Provides the makeRequest helper

void main() {
  const fileContent = '0123456789ABCDEF'; // 16 bytes
  late Handler handler;

  setUp(() async {
    await d.dir('', [
      d.file('test_file.txt', fileContent),
      d.file('image.jpg'),
    ]).create();
    handler = createStaticHandler(
        cacheControl: (final _, final __) => null, d.sandbox);
  });

  test(
      'Given Cache-Control header is set on the server'
      'when a file is served, '
      'then the response includes the specified Cache-Control header',
      () async {
    final cacheControl = CacheControlHeader(
      maxAge: 3600,
      publicCache: true,
      mustRevalidate: true,
    );
    handler = createStaticHandler(
      d.sandbox,
      cacheControl: (final _, final __) => cacheControl,
    );

    final response = await makeRequest(handler, '/test_file.txt');

    expect(response.statusCode, HttpStatus.ok);
    expect(response.headers.cacheControl, isNotNull);
    expect(response.headers.cacheControl!.maxAge, 3600);
    expect(response.headers.cacheControl!.publicCache, isTrue);
    expect(response.headers.cacheControl!.mustRevalidate, isTrue);
  });

  test(
      'Given no Cache-Control header is specified on the server, '
      'when a file is served, '
      'then the response includes no Cache-Control header', () async {
    final response = await makeRequest(handler, '/test_file.txt');

    expect(response.statusCode, HttpStatus.ok);
    expect(response.headers.cacheControl, isNull);
  });

  test(
      'Given Cache-Control header is set on the server for some files '
      'when such a file is served, '
      'then the response includes the specified Cache-Control header '
      'otherwise not', () async {
    final cacheControl = CacheControlHeader(
      maxAge: 3600,
      publicCache: true,
      mustRevalidate: true,
    );
    handler = createStaticHandler(
      d.sandbox,
      cacheControl: (final _, final fileInfo) =>
          fileInfo.file.path.endsWith('jpg') ? cacheControl : null,
    );
    var response = await makeRequest(handler, '/image.jpg');
    expect(response.statusCode, HttpStatus.ok);
    expect(response.headers.cacheControl, isNotNull);
    expect(response.headers.cacheControl!.maxAge, 3600);
    expect(response.headers.cacheControl!.publicCache, isTrue);
    expect(response.headers.cacheControl!.mustRevalidate, isTrue);

    response = await makeRequest(handler, '/test_file.txt');
    expect(response.statusCode, HttpStatus.ok);
    expect(response.headers.cacheControl, isNull);
  });
}
