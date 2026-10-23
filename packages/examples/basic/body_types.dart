import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:relic/relic.dart';

// doctag<body-describe>
void describe(String label, Body body) {
  final type = body.bodyType?.toHeaderValue() ?? '(none)';
  stdout.writeln(
    '${label.padRight(20)} ${type.padRight(33)} ${body.contentLength} bytes',
  );
}
// end:doctag<body-describe>

Future<void> main() async {
  // doctag<body-from-string>
  describe('plain text', Body.fromString('Hello, World!'));
  describe('JSON', Body.fromString('{"message": "Hello"}'));
  describe('HTML', Body.fromString('<!DOCTYPE html><html></html>'));
  describe('XML', Body.fromString('<?xml version="1.0"?><note/>'));
  describe('accents and emoji', Body.fromString('Héllo 🌍'));
  describe('Latin-1', Body.fromString('Héllo', encoding: latin1));
  describe('CSV', Body.fromString('a,b\n1,2\n', mimeType: MimeType.csv));
  // end:doctag<body-from-string>

  // doctag<body-from-data>
  final png = Uint8List.fromList([0x89, 0x50, 0x4E, 0x47, 13, 10, 26, 10]);
  describe('PNG signature', Body.fromData(png));
  describe('PDF signature', Body.fromData(ascii.encode('%PDF-1.7')));
  describe('unknown bytes', Body.fromData(Uint8List.fromList([1, 2, 3])));
  describe(
    'bytes as SVG',
    Body.fromData(
      utf8.encode('<svg/>'),
      mimeType: MimeType.parse('image/svg+xml'),
    ),
  );
  describe('empty', Body.empty());
  // end:doctag<body-from-data>

  // doctag<body-read-once>
  final body = Body.fromString('Hello');
  final bytes = await body.readAll();
  stdout.writeln('read ${bytes.length} bytes');
  try {
    await body.readAll();
  } on StateError catch (error) {
    stdout.writeln(error);
  }
  // end:doctag<body-read-once>

  // doctag<body-max-length>
  try {
    await Body.fromString('x' * 100).readAll(maxLength: 10);
  } on MaxBodySizeExceeded catch (error) {
    stdout.writeln(error);
  }
  // end:doctag<body-max-length>
}
