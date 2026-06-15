import 'package:relic_core/src/headers/typed/primitives/etag_value.dart';
import 'package:test/test.dart';

void main() {
  group('ETagValue construction', () {
    group('Given a strong tag with valid etagc content,', () {
      test('when constructed, '
          'then value and isWeak are preserved.', () {
        final t = ETagValue(value: 'abc123');

        expect(t.value, equals('abc123'));
        expect(t.isWeak, isFalse);
      });
    });

    group('Given a weak tag,', () {
      test('when constructed with isWeak: true, '
          'then the weak flag is set.', () {
        final t = ETagValue(value: 'abc', isWeak: true);

        expect(t.isWeak, isTrue);
      });
    });

    group('Given an opaque-tag value containing a double quote,', () {
      test('when constructed, '
          'then it throws a FormatException.', () {
        expect(() => ETagValue(value: 'abc"def'), throwsFormatException);
      });
    });

    group('Given an opaque-tag value containing a control character,', () {
      test('when constructed, '
          'then it throws a FormatException.', () {
        expect(() => ETagValue(value: 'a\tb'), throwsFormatException);
        expect(() => ETagValue(value: 'a\nb'), throwsFormatException);
        expect(() => ETagValue(value: 'a\x01b'), throwsFormatException);
      });
    });

    group('Given an empty opaque-tag value,', () {
      test('when constructed, '
          'then it is accepted.', () {
        expect(ETagValue(value: '').value, equals(''));
      });
    });
  });

  group('ETagValue.parse', () {
    group('Given a quoted strong tag,', () {
      test('when parsed, '
          'then value is the opaque-tag and isWeak is false.', () {
        final t = ETagValue.parse('"abc123"');

        expect(t.value, equals('abc123'));
        expect(t.isWeak, isFalse);
      });
    });

    group('Given a quoted weak tag,', () {
      test('when parsed, '
          'then isWeak is true and value is the opaque-tag.', () {
        final t = ETagValue.parse('W/"abc"');

        expect(t.value, equals('abc'));
        expect(t.isWeak, isTrue);
      });
    });

    group('Given lowercase "w/" prefix,', () {
      test(
        'when parsed, '
        'then it throws a FormatException (weak marker is case-sensitive).',
        () {
          expect(() => ETagValue.parse('w/"abc"'), throwsFormatException);
        },
      );
    });

    group('Given a value with no surrounding quotes,', () {
      test('when parsed, '
          'then it throws a FormatException.', () {
        expect(() => ETagValue.parse('abc'), throwsFormatException);
      });
    });

    group('Given a missing closing quote,', () {
      test('when parsed, '
          'then it throws a FormatException.', () {
        expect(() => ETagValue.parse('"abc'), throwsFormatException);
      });
    });

    group('Given an empty quoted tag,', () {
      test('when parsed, '
          'then it is accepted with an empty value.', () {
        final t = ETagValue.parse('""');

        expect(t.value, equals(''));
        expect(t.isWeak, isFalse);
      });
    });
  });

  group('ETagValue.encode', () {
    group('Given a strong tag,', () {
      test('when encoded, '
          'then the wire form has no W/ prefix.', () {
        expect(ETagValue(value: 'abc').encode(), equals('"abc"'));
      });
    });

    group('Given a weak tag,', () {
      test('when encoded, '
          'then the wire form has the W/ prefix.', () {
        expect(
          ETagValue(value: 'abc', isWeak: true).encode(),
          equals('W/"abc"'),
        );
      });
    });

    group('Given a tag round-tripped through parse,', () {
      test('when re-encoded, '
          'then the wire form matches the input.', () {
        for (final input in const ['""', '"abc"', '"a/b-c.d"', 'W/"abc"']) {
          expect(ETagValue.parse(input).encode(), equals(input));
        }
      });
    });
  });

  group('ETagValue match helpers', () {
    group('Given two strong tags with identical opaque-tags,', () {
      test('when compared with strongMatches, '
          'then they match.', () {
        final a = ETagValue(value: 'abc');
        final b = ETagValue(value: 'abc');

        expect(a.strongMatches(b), isTrue);
        expect(a.weakMatches(b), isTrue);
      });
    });

    group('Given a strong and a weak tag with the same opaque-tag,', () {
      test('when compared, '
          'then they fail strong match but pass weak match.', () {
        final strong = ETagValue(value: 'abc');
        final weak = ETagValue(value: 'abc', isWeak: true);

        expect(strong.strongMatches(weak), isFalse);
        expect(strong.weakMatches(weak), isTrue);
      });
    });

    group('Given two weak tags with the same opaque-tag,', () {
      test('when compared, '
          'then they fail strong match but pass weak match.', () {
        final a = ETagValue(value: 'abc', isWeak: true);
        final b = ETagValue(value: 'abc', isWeak: true);

        expect(a.strongMatches(b), isFalse);
        expect(a.weakMatches(b), isTrue);
      });
    });

    group('Given two tags with different opaque-tags,', () {
      test('when compared, '
          'then they fail both strong and weak match.', () {
        final a = ETagValue(value: 'abc');
        final b = ETagValue(value: 'def');

        expect(a.strongMatches(b), isFalse);
        expect(a.weakMatches(b), isFalse);
      });
    });
  });

  group('ETagValue equality', () {
    group('Given two tags with same parts,', () {
      test('when compared with ==, '
          'then they are equal and share hashCode.', () {
        final a = ETagValue(value: 'abc', isWeak: true);
        final b = ETagValue(value: 'abc', isWeak: true);

        expect(a, equals(b));
        expect(a.hashCode, equals(b.hashCode));
      });
    });

    group('Given two tags that differ only in weak flag,', () {
      test('when compared with ==, '
          'then they are not equal.', () {
        final a = ETagValue(value: 'abc');
        final b = ETagValue(value: 'abc', isWeak: true);

        expect(a, isNot(equals(b)));
      });
    });
  });
}
