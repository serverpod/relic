import 'dart:io';

import 'package:mime/mime.dart';
import 'package:relic/relic.dart';
import 'package:test/test.dart';
import 'package:test_descriptor/test_descriptor.dart' as d;

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
    await d.file('no_extension', 'content without extension').create();
    handler = createStaticHandler(d.sandbox);
  });

  group('Given files with different extensions', () {
    test(
        'Given an HTML file, '
        'when requested, '
        'then the Content-Type is text/html', () async {
      final response = await makeRequest(handler, '/test.html');

      expect(response.statusCode, HttpStatus.ok);
      expect(response.body.bodyType!.mimeType.primaryType, 'text');
      expect(response.body.bodyType!.mimeType.subType, 'html');
    });

    test(
        'Given a JSON file, '
        'when requested, '
        'then the Content-Type is application/json', () async {
      final response = await makeRequest(handler, '/test.json');

      expect(response.statusCode, HttpStatus.ok);
      expect(response.body.bodyType!.mimeType.primaryType, 'application');
      expect(response.body.bodyType!.mimeType.subType, 'json');
    });

    test(
        'Given a CSS file, '
        'when requested, '
        'then the Content-Type is text/css', () async {
      final response = await makeRequest(handler, '/test.css');

      expect(response.statusCode, HttpStatus.ok);
      expect(response.body.bodyType!.mimeType.primaryType, 'text');
      expect(response.body.bodyType!.mimeType.subType, 'css');
    });

    test(
        'Given a JavaScript file, '
        'when requested, '
        'then the Content-Type is text/javascript or application/javascript',
        () async {
      final response = await makeRequest(handler, '/test.js');

      expect(response.statusCode, HttpStatus.ok);
      final mimeType = response.body.bodyType!.mimeType;
      expect(mimeType.subType, 'javascript');
      // Accept either text/javascript or application/javascript
      expect(['text', 'application'], contains(mimeType.primaryType));
    });

    test(
        'Given a plain text file, '
        'when requested, '
        'then the Content-Type is text/plain', () async {
      final response = await makeRequest(handler, '/test.txt');

      expect(response.statusCode, HttpStatus.ok);
      expect(response.body.bodyType!.mimeType.primaryType, 'text');
      expect(response.body.bodyType!.mimeType.subType, 'plain');
    });

    test(
        'Given an XML file, '
        'when requested, '
        'then the Content-Type is text/xml or application/xml', () async {
      final response = await makeRequest(handler, '/test.xml');

      expect(response.statusCode, HttpStatus.ok);
      final mimeType = response.body.bodyType!.mimeType;
      expect(mimeType.subType, 'xml');
      // Accept either text/xml or application/xml
      expect(['text', 'application'], contains(mimeType.primaryType));
    });

    test(
        'Given a PDF file, '
        'when requested, '
        'then the Content-Type is application/pdf', () async {
      final response = await makeRequest(handler, '/test.pdf');

      expect(response.statusCode, HttpStatus.ok);
      expect(response.body.bodyType!.mimeType.primaryType, 'application');
      expect(response.body.bodyType!.mimeType.subType, 'pdf');
    });

    test(
        'Given a JPEG image file, '
        'when requested, '
        'then the Content-Type is image/jpeg', () async {
      final response = await makeRequest(handler, '/image.jpg');

      expect(response.statusCode, HttpStatus.ok);
      expect(response.body.bodyType!.mimeType.primaryType, 'image');
      expect(response.body.bodyType!.mimeType.subType, 'jpeg');
    });

    test(
        'Given a PNG image file, '
        'when requested, '
        'then the Content-Type is image/png', () async {
      final response = await makeRequest(handler, '/image.png');

      expect(response.statusCode, HttpStatus.ok);
      expect(response.body.bodyType!.mimeType.primaryType, 'image');
      expect(response.body.bodyType!.mimeType.subType, 'png');
    });

    test(
        'Given a GIF image file, '
        'when requested, '
        'then the Content-Type is image/gif', () async {
      final response = await makeRequest(handler, '/image.gif');

      expect(response.statusCode, HttpStatus.ok);
      expect(response.body.bodyType!.mimeType.primaryType, 'image');
      expect(response.body.bodyType!.mimeType.subType, 'gif');
    });

    test(
        'Given a file without extension, '
        'when requested, '
        'then the Content-Type defaults to application/octet-stream', () async {
      final response = await makeRequest(handler, '/no_extension');

      expect(response.statusCode, HttpStatus.ok);
      expect(response.body.bodyType!.mimeType.primaryType, 'application');
      expect(response.body.bodyType!.mimeType.subType, 'octet-stream');
    });
  });

  group('Given a custom MIME type resolver', () {
    test(
        'Given a custom MIME resolver that maps .txt to application/x-my-text, '
        'when a .txt file is requested, '
        'then the Content-Type is application/x-my-text', () async {
      final customResolver = MimeTypeResolver()
        ..addExtension('txt', 'application/x-my-text');
      handler = createStaticHandler(d.sandbox, mimeResolver: customResolver);

      final response = await makeRequest(handler, '/test.txt');

      expect(response.statusCode, HttpStatus.ok);
      expect(response.body.bodyType!.mimeType.primaryType, 'application');
      expect(response.body.bodyType!.mimeType.subType, 'x-my-text');
    });

    test(
        'Given a custom MIME resolver that maps .custom to text/custom, '
        'when a .custom file is requested, '
        'then the Content-Type is text/custom', () async {
      await d.file('test.custom', 'custom file content').create();
      final customResolver = MimeTypeResolver()
        ..addExtension('custom', 'text/custom');
      handler = createStaticHandler(d.sandbox, mimeResolver: customResolver);

      final response = await makeRequest(handler, '/test.custom');

      expect(response.statusCode, HttpStatus.ok);
      expect(response.body.bodyType!.mimeType.primaryType, 'text');
      expect(response.body.bodyType!.mimeType.subType, 'custom');
    });
  });

  group('Given text files with charset encoding', () {
    test(
        'Given a text file, '
        'when requested, '
        'then the Content-Type includes charset=utf-8', () async {
      final response = await makeRequest(handler, '/test.html');

      expect(response.statusCode, HttpStatus.ok);
      final mimeType = response.body.bodyType!.mimeType;
      expect(mimeType.isText, isTrue);
      // For text files, the encoding should be set to UTF-8
      expect(response.body.bodyType?.encoding?.name, 'utf-8');
    });

    test(
        'Given a non-text file, '
        'when requested, '
        'then the Content-Type does not include charset', () async {
      final response = await makeRequest(handler, '/image.jpg');

      expect(response.statusCode, HttpStatus.ok);
      final mimeType = response.body.bodyType!.mimeType;
      expect(mimeType.isText, isFalse);
      // For binary files, encoding should be null
      expect(response.body.bodyType?.encoding, isNull);
    });
  });
}
