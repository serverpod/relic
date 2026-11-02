import 'dart:typed_data';

import 'package:relic_core/relic_core.dart';
import 'package:relic_core/src/headers/codecs/common_types_codecs.dart'
    show parseIntBytes;
import 'package:test/test.dart';

/// Counts the decodes and keeps the bytes the last one saw.
final class _Counting {
  var decoded = 0;
  Uint8List? last;

  late final accessor = HeaderAccessor<int>(
    const HeaderName.custom('x-count'),
    HeaderCodec.bytes((final raw) {
      decoded++;
      last = raw;
      return int.parse(String.fromCharCodes(raw));
    }, encodeInt),
  );
}

Headers _byteHeaders(final String value) =>
    Headers.fromStore(ByteHeaderStore.encode([('X-Count', value)]));

void main() {
  test('Given a byte store, when read through a bytes codec, '
      'then the decoder runs once over the wire bytes', () {
    final counting = _Counting();
    final headers = _byteHeaders('123');

    expect(headers(counting.accessor), 123);
    expect(counting.decoded, 1);
    expect(counting.last, '123'.codeUnits);
  });

  test('Given a byte store, when the same header is read twice, '
      'then it is decoded once', () {
    final counting = _Counting();
    final headers = _byteHeaders('123');

    headers(counting.accessor);
    headers.get(counting.accessor);
    expect(counting.decoded, 1);
  });

  test('Given a map store, when read through a bytes codec, '
      'then the decoder runs over the Latin-1 bytes of the text', () {
    final counting = _Counting();
    final headers = Headers.fromMap({
      'x-count': ['7'],
    });

    expect(headers(counting.accessor), 7);
    expect(counting.decoded, 1);
    expect(counting.last, '7'.codeUnits);
  });

  test('Given a byte store with a Content-Length, '
      'when read through the standard accessor, '
      'then the int comes from the bytes', () {
    final headers = Headers.fromStore(
      ByteHeaderStore.encode(const [('Content-Length', '4096')]),
    );
    expect(headers.contentLength, 4096);
  });

  group('Given parseIntBytes', () {
    Uint8List bytes(final String s) => Uint8List.fromList(s.codeUnits);

    test('when the bytes are digits, then it parses them', () {
      expect(parseIntBytes(bytes('0')), 0);
      expect(parseIntBytes(bytes('123456789012345678')), 123456789012345678);
    });

    test('when the bytes are not plain digits, '
        'then it reads them as parseInt reads the text', () {
      for (final text in [
        '',
        '-1',
        '+1',
        ' 1',
        '1e3',
        '0x10',
        '1234567890123456789',
      ]) {
        Object? fromBytes;
        Object? fromText;
        try {
          fromBytes = parseIntBytes(bytes(text));
        } on FormatException catch (e) {
          fromBytes = e.message;
        }
        try {
          fromText = parseInt(text);
        } on FormatException catch (e) {
          fromText = e.message;
        }
        expect(fromBytes, fromText, reason: '"$text"');
      }
    });
  });
}
