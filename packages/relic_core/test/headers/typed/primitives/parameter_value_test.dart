import 'package:relic_core/src/headers/typed/primitives/header_scanner.dart';
import 'package:relic_core/src/headers/typed/primitives/parameter_value.dart';
import 'package:test/test.dart';

void main() {
  group('ParameterValue construction', () {
    group('Given a token-shaped string,', () {
      test('when constructed, '
          'then value is preserved.', () {
        expect(ParameterValue('gzip').value, equals('gzip'));
        expect(ParameterValue('X-Foo').value, equals('X-Foo'));
      });
    });

    group('Given a string containing spaces or specials,', () {
      test('when constructed, '
          'then it is accepted (output will use quoted-string form).', () {
        expect(ParameterValue('hello world').value, equals('hello world'));
        expect(ParameterValue('semi;colon').value, equals('semi;colon'));
        expect(ParameterValue('with "quotes"').value, equals('with "quotes"'));
      });
    });

    group('Given the empty string,', () {
      test('when constructed, '
          'then it is accepted and encodes as empty quoted-string.', () {
        expect(ParameterValue('').encode(), equals('""'));
      });
    });

    group('Given a string containing control characters,', () {
      test('when constructed, '
          'then it throws a FormatException.', () {
        expect(() => ParameterValue('a\nb'), throwsFormatException);
        expect(() => ParameterValue('a\x01b'), throwsFormatException);
        expect(() => ParameterValue('a\x7fb'), throwsFormatException);
      });
    });

    group('Given a string containing code units above 0xFF,', () {
      test('when constructed, '
          'then it throws a FormatException.', () {
        expect(() => ParameterValue('café'), returnsNormally);
        expect(() => ParameterValue('Ā'), throwsFormatException);
      });
    });
  });

  group('ParameterValue.encode', () {
    group('Given a value that is a valid token,', () {
      test('when encoded, '
          'then the bare-token form is used.', () {
        expect(ParameterValue('gzip').encode(), equals('gzip'));
        expect(ParameterValue('X-Foo').encode(), equals('X-Foo'));
      });
    });

    group('Given a value that is not a valid token,', () {
      test('when encoded, '
          'then the quoted-string form is used.', () {
        expect(ParameterValue('hello world').encode(), equals('"hello world"'));
        expect(ParameterValue('with/slash').encode(), equals('"with/slash"'));
      });
    });

    group('Given a value containing characters that need escaping,', () {
      test('when encoded, '
          'then DQUOTE and backslash are escaped with quoted-pair.', () {
        expect(
          ParameterValue(r'with "quote"').encode(),
          equals(r'"with \"quote\""'),
        );
        expect(
          ParameterValue(r'with\backslash').encode(),
          equals(r'"with\\backslash"'),
        );
      });
    });

    group('Given a parameter value round-tripped through scanner,', () {
      test('when re-parsed via ParameterValue.read, '
          'then the value is preserved.', () {
        for (final raw in const [
          'gzip',
          'hello world',
          r'with "quote"',
          r'with\backslash',
          '',
        ]) {
          final encoded = ParameterValue(raw).encode();
          final scanner = HeaderScanner(encoded);
          final parsed = ParameterValue.read(scanner);

          expect(parsed.value, equals(raw));
          expect(scanner.atEnd, isTrue);
        }
      });
    });
  });

  group('ParameterValue.read', () {
    group('Given a scanner positioned at a token,', () {
      test('when read is called, '
          'then the token bytes form the value.', () {
        final s = HeaderScanner('gzip');

        expect(ParameterValue.read(s).value, equals('gzip'));
      });
    });

    group('Given a scanner positioned at a quoted-string with escapes,', () {
      test('when read is called, '
          'then the value is unescaped.', () {
        final s = HeaderScanner(r'"a\"b\\c"');

        expect(ParameterValue.read(s).value, equals(r'a"b\c'));
      });
    });

    group('Given a scanner positioned at neither a token nor a quote,', () {
      test('when read is called, '
          'then it throws a FormatException.', () {
        final s = HeaderScanner(' leading-space');

        expect(() => ParameterValue.read(s), throwsFormatException);
      });
    });
  });

  group('ParameterValue equality', () {
    group('Given two ParameterValues with identical content,', () {
      test('when compared, '
          'then they are equal and share hashCode.', () {
        final a = ParameterValue('hello world');
        final b = ParameterValue('hello world');

        expect(a, equals(b));
        expect(a.hashCode, equals(b.hashCode));
      });
    });

    group('Given two ParameterValues that differ only in case,', () {
      test('when compared, '
          'then they are not equal (case-sensitive value comparison).', () {
        expect(ParameterValue('gzip') == ParameterValue('GZIP'), isFalse);
      });
    });
  });
}
