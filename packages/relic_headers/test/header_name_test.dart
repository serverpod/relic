import 'dart:typed_data';

import 'package:relic_headers/relic_headers.dart';
import 'package:test/test.dart';

void main() {
  test('Given the known table, when read, '
      'then every id is its index and every name is a lowercase token', () {
    for (final (index, name) in HeaderName.known.indexed) {
      expect(name.id, index);
      expect(name.lower, name.lower.toLowerCase());
      expect(HeaderName.isToken(name.lower), isTrue);
    }
    expect(
      HeaderName.known.map((n) => n.lower).toSet().length,
      HeaderName.known.length,
      reason: 'no duplicate names',
    );
  });

  for (final variant in ['lower', 'UPPER', 'Mixed']) {
    test('Given every known name spelled $variant, when looked up as bytes, '
        'then the known name is returned', () {
      for (final known in HeaderName.known) {
        final spelled = switch (variant) {
          'UPPER' => known.lower.toUpperCase(),
          'Mixed' => _mixedCase(known.lower),
          _ => known.lower,
        };
        final bytes = Uint8List.fromList('xx$spelled: v'.codeUnits);
        final found = HeaderName.lookupBytes(bytes, 2, 2 + spelled.length);
        expect(found, same(known), reason: spelled);
      }
    });

    test('Given every known name spelled $variant, when looked up as text, '
        'then the known name is returned', () {
      for (final known in HeaderName.known) {
        final spelled = switch (variant) {
          'UPPER' => known.lower.toUpperCase(),
          'Mixed' => _mixedCase(known.lower),
          _ => known.lower,
        };
        expect(HeaderName.lookup(spelled), same(known), reason: spelled);
      }
    });
  }

  test(
    'Given bytes of an unknown name, when looked up, then null is returned',
    () {
      final bytes = Uint8List.fromList('x-custom-header'.codeUnits);
      expect(HeaderName.lookupBytes(bytes, 0, bytes.length), isNull);
    },
  );

  test('Given bytes that differ from a known name by one byte, '
      'when looked up, then null is returned', () {
    final bytes = Uint8List.fromList('content-typo'.codeUnits);
    expect(HeaderName.lookupBytes(bytes, 0, bytes.length), isNull);
  });

  test('Given a byte that only folds to a known letter, when looked up, '
      'then it does not match', () {
    // 0x03 | 0x20 is 0x23, not a letter. Control bytes must not match.
    final bytes = Uint8List.fromList([0x03, ...'ost'.codeUnits]);
    expect(HeaderName.lookupBytes(bytes, 0, 4), isNull);
  });

  test(
    'Given a known name with a control character that folds to its hyphen or digit, '
    'when looked up, '
    'then it does not match',
    () {
      final hyphen = Uint8List.fromList('content\rtype'.codeUnits);
      expect(HeaderName.lookupBytes(hyphen, 0, hyphen.length), isNull);
      expect(() => HeaderName.lookup('content\rtype'), throwsFormatException);
      expect(() => HeaderName.lookup('content-md\x15'), throwsFormatException);
    },
  );

  test('Given an unknown token, when looked up as text, '
      'then a lowercase unknown name is returned', () {
    final name = HeaderName.lookup('X-Custom-Thing');
    expect(name.id, -1);
    expect(name.lower, 'x-custom-thing');
    expect(name, HeaderName.lookup('x-custom-thing'));
    expect(name.hashCode, HeaderName.lookup('x-custom-thing').hashCode);
    expect(name, const HeaderName.custom('x-custom-thing'));
  });

  test('Given a name that is not a token, when looked up, '
      'then a FormatException is thrown', () {
    expect(() => HeaderName.lookup(''), throwsFormatException);
    expect(() => HeaderName.lookup('bad name'), throwsFormatException);
    expect(() => HeaderName.lookup('bad:name'), throwsFormatException);
    expect(() => HeaderName.lookup('bad\r\nname'), throwsFormatException);
  });

  test('Given a known name and an unknown name with the same text, '
      'when compared, then they are not equal', () {
    expect(const HeaderName.custom('host'), isNot(HeaderName.host));
  });

  test('Given a known name, when converted to a string, '
      'then it is the lowercase name', () {
    expect(HeaderName.contentType.toString(), 'content-type');
  });
}

String _mixedCase(String s) => [
  for (final (i, c) in s.split('').indexed) i.isEven ? c.toUpperCase() : c,
].join();
