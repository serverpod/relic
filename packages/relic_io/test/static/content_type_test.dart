import 'dart:io';

import 'package:mime/mime.dart';
import 'package:relic_core/relic_core.dart';
import 'package:relic_io/relic_io.dart';
import 'package:test/test.dart';
import 'package:test_descriptor/test_descriptor.dart' as d;
import 'package:test_utils/test_utils.dart';

import 'test_util.dart'; // Provides the makeRequest helper

void main() {
  late Handler handler;

  setUp(() async {
    // Create files with different extensions
    await d.file('test.html', '<html><body>Hello</body></html>').create();
    await d.file('test.json', '{"key": "value"}').create();
    await d.file('test.css', 'body { color: red; }').create();
    await d.file('test.js', 'console.log("hello");').create();
    await d.file('test.txt', 'Plain text content').create();
    await d.file('test.xml', '<?xml version="1.0"?><root></root>').create();
    await d.file('test.pdf', 'fake pdf content').create();
    await d.file('image.jpg', 'fake jpeg content').create();
    await d.file('image.png', 'fake png content').create();
    await d.file('image.gif', 'fake gif content').create();
    await d.file('image.svg', '<svg></svg>').create();
    await d.file('app.wasm', 'fake wasm content').create();
    await d.file('no_extension', 'content without extension').create();
    handler = StaticHandler.directory(
      Directory(d.sandbox),
      cacheControl: (_, _) => null,
    ).asHandler;
  });

  parameterizedTest(
    (final v) =>
        'Given a file "${v.key}", '
        'when requested, '
        'then the mimetype is "${v.value.toHeaderValue()}"',
    variants: {
      '/test.html': MimeType.html,
      '/test.json': MimeType.json,
      '/test.css': MimeType.css,
      '/test.js': MimeType.javascript,
      '/test.txt': MimeType.plainText,
      '/test.xml': MimeType.xml,
      '/test.pdf': MimeType.pdf,
      '/image.jpg': const MimeType('image', 'jpeg'),
      '/image.png': const MimeType('image', 'png'),
      '/image.gif': const MimeType('image', 'gif'),
      '/image.svg': const MimeType('image', 'svg+xml'),
      '/app.wasm': const MimeType('application', 'wasm'),
      '/no_extension': MimeType.octetStream,
    }.entries,
    (final v) async {
      final fileName = v.key;
      final mimeType = v.value;

      final response = await makeRequest(handler, fileName);

      expect(response.statusCode, HttpStatus.ok);
      expect(response.body.bodyType!.mimeType, mimeType);
    },
  );

  group('Given a custom MIME type resolver', () {
    test(
      'Given a custom MIME resolver that maps .txt to application/x-my-text, '
      'when a .txt file is requested, '
      'then the Content-Type is application/x-my-text',
      () async {
        final customResolver = MimeTypeResolver()
          ..addExtension('txt', 'application/x-my-text');
        handler = StaticHandler.directory(
          Directory(d.sandbox),
          cacheControl: (_, _) => null,
          mimeResolver: customResolver,
        ).asHandler;

        final response = await makeRequest(handler, '/test.txt');

        expect(response.statusCode, HttpStatus.ok);
        expect(response.body.bodyType!.mimeType.primaryType, 'application');
        expect(response.body.bodyType!.mimeType.subType, 'x-my-text');
      },
    );

    test('Given a custom MIME resolver that maps .custom to text/custom, '
        'when a .custom file is requested, '
        'then the Content-Type is text/custom', () async {
      await d.file('test.custom', 'custom file content').create();
      final customResolver = MimeTypeResolver()
        ..addExtension('custom', 'text/custom');
      handler = StaticHandler.directory(
        Directory(d.sandbox),
        cacheControl: (_, _) => null,
        mimeResolver: customResolver,
      ).asHandler;

      final response = await makeRequest(handler, '/test.custom');

      expect(response.statusCode, HttpStatus.ok);
      expect(response.body.bodyType!.mimeType.primaryType, 'text');
      expect(response.body.bodyType!.mimeType.subType, 'custom');
    });
  });

  test('Given a text file, '
      'when requested, '
      'then the Content-Type includes charset=utf-8', () async {
    final response = await makeRequest(handler, '/test.html');

    expect(response.statusCode, HttpStatus.ok);
    final mimeType = response.body.bodyType!.mimeType;
    expect(mimeType.isText, isTrue);
    // For text files, the encoding should be set to UTF-8
    expect(response.body.bodyType?.encoding?.name, 'utf-8');
  });

  test('Given a non-text file, '
      'when requested, '
      'then the Content-Type does not include charset', () async {
    final response = await makeRequest(handler, '/image.jpg');

    expect(response.statusCode, HttpStatus.ok);
    final mimeType = response.body.bodyType!.mimeType;
    expect(mimeType.isText, isFalse);
    // For binary files, encoding should be null
    expect(response.body.bodyType?.encoding, isNull);
  });
}
