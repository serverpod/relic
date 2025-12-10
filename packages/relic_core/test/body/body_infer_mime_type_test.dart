import 'dart:convert';
import 'dart:typed_data';

import 'package:relic_core/relic_core.dart';
import 'package:test/test.dart';

void main() {
  test('Given JSON content without explicit mimeType, '
      'when Body.fromString is called, '
      'then it infers application/json', () {
    const jsonContent = '{"key": "value"}';
    final body = Body.fromString(jsonContent);
    expect(body.bodyType?.mimeType, MimeType.json);
  });

  test('Given HTML content without explicit mimeType, '
      'when Body.fromString is called, '
      'then it infers text/html', () {
    const htmlContent = '<!DOCTYPE html><html><body>Hello</body></html>';
    final body = Body.fromString(htmlContent);
    expect(body.bodyType?.mimeType, MimeType.html);
  });

  test('Given HTML content with whitespace prefix, '
      'when Body.fromString is called, '
      'then it infers text/html', () {
    const htmlContentWithWhitespace =
        ' \t  \n   \r     ' // some whitespace
        '<!DOCTYPE html><html><body>Hello</body></html>'; // followed by html
    final body = Body.fromString(htmlContentWithWhitespace);
    expect(body.bodyType?.mimeType, MimeType.html);
  });

  test('Given XML content without explicit mimeType, '
      'when Body.fromString is called, '
      'then it infers application/xml', () {
    const xmlContent = '<?xml version="1.0"?><root></root>';
    final body = Body.fromString(xmlContent);
    expect(body.bodyType?.mimeType, MimeType.xml);
  });

  test('Given plain text content without explicit mimeType, '
      'when Body.fromString is called, '
      'then it defaults to text/plain', () {
    const plainTextContent = 'Just some plain text';
    final body = Body.fromString(plainTextContent);
    expect(body.bodyType?.mimeType, MimeType.plainText);
  });

  test('Given empty string without explicit mimeType, '
      'when Body.fromString is called, '
      'then it defaults to text/plain', () {
    const emptyContent = '';
    final body = Body.fromString(emptyContent);
    expect(body.bodyType?.mimeType, MimeType.plainText);
  });

  test('Given JSON content with explicit mimeType, '
      'when Body.fromString is called, '
      'then it uses the explicit mimeType', () {
    const jsonContent = '{"key": "value"}';
    final body = Body.fromString(jsonContent, mimeType: MimeType.plainText);
    expect(body.bodyType?.mimeType, MimeType.plainText);
  });

  test('Given content with custom encoding, '
      'when Body.fromString is called, '
      'then it preserves the encoding', () {
    const content = 'Héllo world';
    final body = Body.fromString(content, encoding: latin1);
    expect(body.bodyType?.encoding, latin1);
  });

  test('Given inferred MIME type, '
      'when Body.fromString is called without encoding, '
      'then it uses utf8 encoding by default', () {
    const jsonContent = '{"key": "value"}';
    final body = Body.fromString(jsonContent);
    expect(body.bodyType?.encoding, utf8);
  });

  test('Given PNG binary data without explicit mimeType, '
      'when Body.fromData is called, '
      'then it infers image/png', () {
    final pngBytes = Uint8List.fromList([
      0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A, // PNG signature
    ]);
    final body = Body.fromData(pngBytes);
    expect(body.bodyType?.mimeType.primaryType, 'image');
    expect(body.bodyType?.mimeType.subType, 'png');
  });

  test('Given JPEG binary data without explicit mimeType, '
      'when Body.fromData is called, '
      'then it infers image/jpeg', () {
    final jpegBytes = Uint8List.fromList([
      0xFF, 0xD8, 0xFF, 0xE0, // JPEG signature
    ]);
    final body = Body.fromData(jpegBytes);
    expect(body.bodyType?.mimeType.primaryType, 'image');
    expect(body.bodyType?.mimeType.subType, 'jpeg');
  });

  test('Given GIF binary data without explicit mimeType, '
      'when Body.fromData is called, '
      'then it infers image/gif', () {
    final gifBytes = Uint8List.fromList(utf8.encode('GIF89a'));
    final body = Body.fromData(gifBytes);
    expect(body.bodyType?.mimeType.primaryType, 'image');
    expect(body.bodyType?.mimeType.subType, 'gif');
  });

  test('Given PDF binary data without explicit mimeType, '
      'when Body.fromData is called, '
      'then it infers application/pdf', () {
    final pdfBytes = Uint8List.fromList(utf8.encode('%PDF-1.4'));
    final body = Body.fromData(pdfBytes);
    expect(body.bodyType?.mimeType, MimeType.pdf);
  });

  test('Given unrecognizable binary data without explicit mimeType, '
      'when Body.fromData is called, '
      'then it defaults to application/octet-stream', () {
    final unknownBytes = Uint8List.fromList([0x00, 0x01, 0x02, 0x03]);
    final body = Body.fromData(unknownBytes);
    expect(body.bodyType?.mimeType, MimeType.octetStream);
  });

  test('Given binary data with explicit mimeType, '
      'when Body.fromData is called, '
      'then it uses the explicit mimeType', () {
    final pngBytes = Uint8List.fromList(
      [0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A], // PNG signature
    );
    final body = Body.fromData(pngBytes, mimeType: MimeType.json);
    expect(body.bodyType?.mimeType, MimeType.json);
  });

  test('Given empty binary data without explicit mimeType, '
      'when Body.fromData is called, '
      'then it defaults to application/octet-stream', () {
    final emptyBytes = Uint8List(0);
    final body = Body.fromData(emptyBytes);
    expect(body.bodyType?.mimeType, MimeType.octetStream);
  });
}
