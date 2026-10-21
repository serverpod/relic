import 'dart:typed_data';

import 'package:relic_core/relic_core.dart';
import 'package:test/test.dart';

/// Counts which path decoded.
final class _Counting {
  var text = 0;
  var bytes = 0;

  late final accessor = HeaderAccessor<int>(
    const HeaderName.custom('x-count'),
    HeaderCodec.single(
      (final s) {
        text++;
        return int.parse(s.trim());
      },
      encodeInt,
      decodeBytes: (final raw) {
        bytes++;
        return parseIntBytes(raw);
      },
    ),
  );
}

Headers _byteHeaders(final String value) =>
    Headers.fromStore(ByteHeaderStore.encode([('X-Count', value)]));

void main() {
  test('Given a byte store with a digits value, when read, '
      'then the bytes path decodes and the text path never runs', () {
    final counting = _Counting();
    final headers = _byteHeaders('123');

    expect(headers(counting.accessor), 123);
    expect(counting.bytes, 1);
    expect(counting.text, 0);
  });

  test('Given a byte store, when the same header is read twice, '
      'then it is decoded once', () {
    final counting = _Counting();
    final headers = _byteHeaders('123');

    headers(counting.accessor);
    headers.get(counting.accessor);
    expect(counting.bytes, 1);
  });

  test('Given a byte store with a value the bytes path declines, '
      'when read, then the text path decodes it and the decline is kept', () {
    final counting = _Counting();
    final headers = _byteHeaders(' 42');

    expect(headers(counting.accessor), 42);
    expect(headers(counting.accessor), 42);
    expect(counting.bytes, 1);
    expect(counting.text, 1);
  });

  test('Given a map store, when read, then only the text path runs', () {
    final counting = _Counting();
    final headers = Headers.fromMap({
      'x-count': ['7'],
    });

    expect(headers(counting.accessor), 7);
    expect(counting.bytes, 0);
    expect(counting.text, 1);
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

    test('when the bytes are not plain digits, then it declines', () {
      expect(parseIntBytes(bytes('')), isNull);
      expect(parseIntBytes(bytes('-1')), isNull);
      expect(parseIntBytes(bytes('+1')), isNull);
      expect(parseIntBytes(bytes(' 1')), isNull);
      expect(parseIntBytes(bytes('1e3')), isNull);
      expect(parseIntBytes(bytes('0x10')), isNull);
      expect(parseIntBytes(bytes('1234567890123456789')), isNull);
    });
  });
}
