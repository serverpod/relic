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
    'Given every code unit, '
    'when asked whether it is a tchar, '
    'then only the digits, the letters and the 15 marks of RFC 9110 are.',
    () {
      const marks = "!#\$%&'*+-.^_`|~";
      const digits = '0123456789';
      const letters = 'abcdefghijklmnopqrstuvwxyz';
      final expected = [
        ...marks.codeUnits,
        ...digits.codeUnits,
        ...letters.toUpperCase().codeUnits,
        ...letters.codeUnits,
      ]..sort();

      final tchars = [
        for (var c = 0; c <= 0xFFFF; c++)
          if (HeaderName.isTchar(c)) c,
      ];

      expect(tchars, expected);
    },
  );

  test('Given a negative code, '
      'when asked whether it is a tchar, '
      'then it is not.', () {
    expect(HeaderName.isTchar(-1), isFalse);
  });

  test('Given a name that differs from a known one by one character, '
      'when looked up, then it is unknown', () {
    expect(HeaderName.lookup('content-typo').id, -1);
  });

  test('Given a character that only folds to a known letter, when looked up, '
      'then it does not match', () {
    // 0x03 | 0x20 is 0x23, not a letter. A control character is not a
    // token character either, so the lookup throws instead of matching.
    expect(() => HeaderName.lookup('\x03ost'), throwsFormatException);
  });

  test(
    'Given a known name with a control character that folds to its hyphen or digit, '
    'when looked up, '
    'then it does not match',
    () {
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

  test(
    'Given a custom name that spells a known name, '
    'when compared with the known name, then they are equal and hash alike',
    () {
      const custom = HeaderName.custom('host');

      expect(custom, HeaderName.host);
      expect(HeaderName.host, custom);
      expect(custom.hashCode, HeaderName.host.hashCode);
    },
  );

  test('Given two custom names, when compared, '
      'then they are equal only with the same text', () {
    expect(const HeaderName.custom('x-a'), const HeaderName.custom('x-a'));
    expect(
      const HeaderName.custom('x-a'),
      isNot(const HeaderName.custom('x-b')),
    );
    expect(const HeaderName.custom('x-a'), isNot(HeaderName.host));
  });

  test('Given a custom name with uppercase, when it is hashed, '
      'then it fails an assert', () {
    expect(
      () => const HeaderName.custom('X-Foo').hashCode,
      throwsA(isA<AssertionError>()),
    );
  });

  test('Given a custom name that is not a token, when it is compared, '
      'then it fails an assert', () {
    expect(
      () => const HeaderName.custom('x foo') == HeaderName.host,
      throwsA(isA<AssertionError>()),
    );
  });

  test('Given a known name, when converted to a string, '
      'then it is the lowercase name', () {
    expect(HeaderName.contentType.toString(), 'content-type');
  });
}

String _mixedCase(String s) => [
  for (final (i, c) in s.split('').indexed) i.isEven ? c.toUpperCase() : c,
].join();
