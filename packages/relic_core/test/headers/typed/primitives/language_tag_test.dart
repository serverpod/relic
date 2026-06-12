import 'package:relic_core/src/headers/typed/primitives/language_tag.dart';
import 'package:test/test.dart';

void main() {
  group('LanguageTag.parse - basic langtag shapes', () {
    group('Given a simple 2-letter language,', () {
      test('when parsed, '
          'then the subtag is lowercased.', () {
        expect(LanguageTag.parse('EN').encode(), equals('en'));
        expect(LanguageTag.parse('en').encode(), equals('en'));
      });
    });

    group('Given a language with ALPHA region,', () {
      test('when parsed, '
          'then language is lowercased and region uppercased.', () {
        expect(LanguageTag.parse('en-us').encode(), equals('en-US'));
        expect(LanguageTag.parse('EN-US').encode(), equals('en-US'));
        expect(LanguageTag.parse('en-US').encode(), equals('en-US'));
      });
    });

    group('Given a language with a digits region (UN M.49),', () {
      test('when parsed, '
          'then the region digits are preserved.', () {
        expect(LanguageTag.parse('es-419').encode(), equals('es-419'));
      });
    });

    group('Given a 3-letter ISO 639 language,', () {
      test('when parsed, '
          'then it is accepted.', () {
        expect(LanguageTag.parse('cmn').encode(), equals('cmn'));
      });
    });

    group('Given an extlang,', () {
      test('when parsed, '
          'then the extlang subtag follows the language.', () {
        expect(
          LanguageTag.parse('zh-cmn-Hans-CN').encode(),
          equals('zh-cmn-Hans-CN'),
        );
      });
    });

    group('Given a language with script and region,', () {
      test('when parsed, '
          'then the script is title-cased.', () {
        expect(LanguageTag.parse('zh-hant-tw').encode(), equals('zh-Hant-TW'));
        expect(LanguageTag.parse('zh-HANT-TW').encode(), equals('zh-Hant-TW'));
      });
    });

    group('Given a language with a variant subtag,', () {
      test('when parsed, '
          'then the variant is lowercased and preserved.', () {
        expect(LanguageTag.parse('de-DE-1996').encode(), equals('de-DE-1996'));
        expect(
          LanguageTag.parse('sl-IT-nedis').encode(),
          equals('sl-IT-nedis'),
        );
      });
    });

    group('Given a language with an extension,', () {
      test('when parsed, '
          'then the singleton and subtags are preserved.', () {
        expect(
          LanguageTag.parse('de-DE-u-co-phonebk').encode(),
          equals('de-DE-u-co-phonebk'),
        );
        expect(
          LanguageTag.parse('en-a-bbb-x-private').encode(),
          equals('en-a-bbb-x-private'),
        );
      });
    });
  });

  group('LanguageTag.parse - private-use', () {
    group('Given a fully private-use tag,', () {
      test('when parsed, '
          'then it is accepted and lowercased.', () {
        expect(LanguageTag.parse('x-foo').encode(), equals('x-foo'));
        expect(LanguageTag.parse('X-FOO-BAR').encode(), equals('x-foo-bar'));
      });
    });

    group('Given a private-use prefix with no subtags,', () {
      test('when parsed, '
          'then it throws a FormatException.', () {
        expect(() => LanguageTag.parse('x'), throwsFormatException);
      });
    });
  });

  group('LanguageTag.parse - grandfathered', () {
    group('Given an irregular grandfathered tag,', () {
      test('when parsed, '
          'then it is accepted as-is in lowercase.', () {
        expect(LanguageTag.parse('i-klingon').encode(), equals('i-klingon'));
        expect(LanguageTag.parse('I-Klingon').encode(), equals('i-klingon'));
        expect(LanguageTag.parse('en-gb-oed').encode(), equals('en-gb-oed'));
      });
    });

    group('Given a non-irregular "i-..." tag,', () {
      test('when parsed, '
          'then it throws a FormatException.', () {
        expect(() => LanguageTag.parse('i-unknownlang'), throwsFormatException);
      });
    });
  });

  group('LanguageTag.parse - rejection cases', () {
    group('Given an empty string,', () {
      test('when parsed, '
          'then it throws a FormatException.', () {
        expect(() => LanguageTag.parse(''), throwsFormatException);
      });
    });

    group('Given a tag with a leading hyphen,', () {
      test('when parsed, '
          'then it throws a FormatException.', () {
        expect(() => LanguageTag.parse('-en'), throwsFormatException);
      });
    });

    group('Given a tag with a trailing hyphen,', () {
      test('when parsed, '
          'then it throws a FormatException.', () {
        expect(() => LanguageTag.parse('en-'), throwsFormatException);
      });
    });

    group('Given a tag with double hyphens,', () {
      test('when parsed, '
          'then it throws a FormatException.', () {
        expect(() => LanguageTag.parse('en--US'), throwsFormatException);
      });
    });

    group('Given a subtag longer than 8 characters,', () {
      test('when parsed, '
          'then it throws a FormatException.', () {
        expect(() => LanguageTag.parse('toolongtag'), throwsFormatException);
      });
    });

    group('Given a non-alphanumeric character in a subtag,', () {
      test('when parsed, '
          'then it throws a FormatException.', () {
        expect(() => LanguageTag.parse('en_US'), throwsFormatException);
        expect(() => LanguageTag.parse('en-U!S'), throwsFormatException);
      });
    });

    group('Given an extension singleton with no subtags,', () {
      test('when parsed, '
          'then it throws a FormatException.', () {
        expect(() => LanguageTag.parse('en-a'), throwsFormatException);
        expect(() => LanguageTag.parse('en-a-b'), throwsFormatException);
      });
    });
  });

  group('LanguageTag equality and round-trip', () {
    group('Given two tags differing only in case,', () {
      test('when compared, '
          'then they are equal.', () {
        expect(LanguageTag.parse('EN-US'), equals(LanguageTag.parse('en-us')));
        expect(
          LanguageTag.parse('zh-HANT-TW'),
          equals(LanguageTag.parse('zh-hant-tw')),
        );
      });

      test('when hashed, '
          'then their hash codes are equal.', () {
        expect(
          LanguageTag.parse('EN-US').hashCode,
          equals(LanguageTag.parse('en-us').hashCode),
        );
      });
    });

    group('Given a parsed tag,', () {
      test('when re-parsed from its encoded form, '
          'then the result is equal to the original.', () {
        for (final input in const [
          'en',
          'en-US',
          'es-419',
          'zh-Hant-TW',
          'zh-cmn-Hans-CN',
          'de-DE-1996',
          'sl-IT-nedis',
          'de-DE-u-co-phonebk',
          'en-a-bbb-x-private',
          'x-foo-bar',
          'i-klingon',
        ]) {
          final parsed = LanguageTag.parse(input);
          expect(LanguageTag.parse(parsed.encode()), equals(parsed));
        }
      });
    });
  });

  group('LanguageTag.parse - duplicate subtags', () {
    group('Given a repeated variant subtag,', () {
      test('when parsed, '
          'then it throws (RFC 5646 2.2.5).', () {
        expect(() => LanguageTag.parse('en-1996-1996'), throwsFormatException);
      });
    });

    group('Given a repeated extension singleton,', () {
      test('when parsed, '
          'then it throws (RFC 5646 2.2.6).', () {
        expect(
          () => LanguageTag.parse('en-a-foo-a-bar'),
          throwsFormatException,
        );
      });
    });
  });
}
