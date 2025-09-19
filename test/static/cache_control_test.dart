import 'dart:io';

import 'package:relic/relic.dart';
import 'package:test/test.dart';
import 'package:test_descriptor/test_descriptor.dart' as d;

import 'test_util.dart'; // Provides the makeRequest helper

void main() {
  const fileContent = '0123456789ABCDEF'; // 16 bytes
  final cacheControl = CacheControlHeader(
    maxAge: 3600,
    publicCache: true,
    mustRevalidate: true,
  );

  setUpAll(() async {
    await d.dir('', [
      d.file('test_file.txt', fileContent),
      d.file('image.jpg'),
    ]).create();
  });

  test(
      'Given Cache-Control header is set on the server'
      'when a file is served, '
      'then the response includes the specified Cache-Control header',
      () async {
    final handler = createStaticHandler(d.sandbox,
        cacheControl: (final _, final __) => cacheControl);
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
    final handler = createStaticHandler(d.sandbox,
        cacheControl: (final _, final __) => null);
    final response = await makeRequest(handler, '/test_file.txt');

    expect(response.statusCode, HttpStatus.ok);
    expect(response.headers.cacheControl, isNull);
  });

  group('Given Cache-Control header is set for a file pattern', () {
    late Handler handler;
    setUpAll(() {
      handler = createStaticHandler(
        d.sandbox,
        cacheControl: (final _, final fileInfo) =>
            fileInfo.file.path.endsWith('jpg') ? cacheControl : null,
      );
    });

    test(
        'when a matching file is served, '
        'then the response includes the specified Cache-Control header',
        () async {
      final response = await makeRequest(handler, '/image.jpg');
      expect(response.statusCode, HttpStatus.ok);
      expect(response.headers.cacheControl, isNotNull);
      expect(response.headers.cacheControl!.maxAge, 3600);
      expect(response.headers.cacheControl!.publicCache, isTrue);
      expect(response.headers.cacheControl!.mustRevalidate, isTrue);
    });

    test(
        'when a non-matching file is served, '
        "then the response doesn't includes the specified Cache-Control header",
        () async {
      final response = await makeRequest(handler, '/test_file.txt');
      expect(response.statusCode, HttpStatus.ok);
      expect(response.headers.cacheControl, isNull);
    });
  });
}
