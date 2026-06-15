import 'package:relic_core/src/headers/typed/primitives/token.dart';
import 'package:test/test.dart';

void main() {
  group('Token validation', () {
    group('Given an empty string,', () {
      test('when checked with Token.isValid, '
          'then it returns false.', () {
        expect(Token.isValid(''), isFalse);
      });

      test('when passed to Token.validate, '
          'then it throws a FormatException.', () {
        expect(() => Token.validate(''), throwsFormatException);
      });
    });

    group('Given a valid tchar character,', () {
      test('when Token.isValid is called for each tchar special, '
          'then every one returns true.', () {
        const specials = "!#\$%&'*+-.^_`|~";
        for (final c in specials.split('')) {
          expect(Token.isValid(c), isTrue, reason: 'tchar special $c');
        }
      });
    });

    group('Given a mixed-case alphanumeric token string,', () {
      test('when checked with Token.isValid, '
          'then it returns true.', () {
        expect(Token.isValid('Bearer'), isTrue);
        expect(Token.isValid('X-Custom-Header'), isTrue);
        expect(Token.isValid('text-encoding-v2.0'), isTrue);
        expect(Token.isValid('MD5'), isTrue);
      });

      test('when passed to Token.validate, '
          'then the original string is returned unchanged.', () {
        expect(Token.validate('gzip'), equals('gzip'));
        expect(Token.validate('GZIP'), equals('GZIP'));
        expect(Token.validate('X-Foo'), equals('X-Foo'));
      });
    });

    group('Given a string containing whitespace,', () {
      test('when checked with Token.isValid, '
          'then it returns false.', () {
        expect(Token.isValid('a b'), isFalse);
        expect(Token.isValid(' '), isFalse);
        expect(Token.isValid('leading-space '), isFalse);
      });

      test('when passed to Token.validate, '
          'then it throws a FormatException.', () {
        expect(() => Token.validate('has space'), throwsFormatException);
      });
    });

    group('Given a string containing RFC 9110 separator characters,', () {
      test('when checked with Token.isValid, '
          'then it returns false for each separator.', () {
        for (final c in '()<>@,;:\\"/[]?={}'.split('')) {
          expect(
            Token.isValid('valid${c}part'),
            isFalse,
            reason: 'separator $c',
          );
        }
      });

      test('when passed to Token.validate, '
          'then it throws a FormatException.', () {
        expect(() => Token.validate('semi;colon'), throwsFormatException);
      });
    });

    group('Given a string containing non-ASCII characters,', () {
      test('when checked with Token.isValid, '
          'then it returns false.', () {
        expect(Token.isValid('café'), isFalse);
        expect(Token.isValid('ÿ'), isFalse);
      });
    });

    group('Given a string containing control characters,', () {
      test('when checked with Token.isValid, '
          'then it returns false.', () {
        expect(Token.isValid('a\tb'), isFalse);
        expect(Token.isValid('a\nb'), isFalse);
        expect(Token.isValid('a\x7fb'), isFalse);
      });
    });
  });

  group('Token.equals and Token.hashFor', () {
    group('Given two TokenValues differing only in ASCII letter case,', () {
      test('when compared with Token.equals, '
          'then they are reported equal.', () {
        expect(Token.equals(TokenValue('gzip'), TokenValue('GZIP')), isTrue);
        expect(Token.equals(TokenValue('X-Foo'), TokenValue('x-foo')), isTrue);
      });

      test('when hashed with Token.hashFor, '
          'then both produce the same hash.', () {
        expect(
          Token.hashFor(TokenValue('Bearer')),
          equals(Token.hashFor(TokenValue('BEARER'))),
        );
      });
    });

    group('Given two TokenValues with different lengths,', () {
      test('when compared with Token.equals, '
          'then they are reported unequal.', () {
        expect(Token.equals(TokenValue('gzip'), TokenValue('gzipx')), isFalse);
      });
    });

    group('Given two TokenValues of the same length with different bytes,', () {
      test('when compared with Token.equals, '
          'then they are reported unequal.', () {
        expect(Token.equals(TokenValue('gzip'), TokenValue('gzpi')), isFalse);
      });
    });

    group('Given two TokenValues mixing letters and tchar specials,', () {
      test('when compared with Token.equals, '
          'then only ASCII letters are case-folded.', () {
        expect(Token.equals(TokenValue('a^b'), TokenValue('A^B')), isTrue);
      });
    });
  });

  group('TokenValue construction', () {
    group('Given an invalid token string,', () {
      test('when passed to the TokenValue constructor, '
          'then it throws a FormatException.', () {
        expect(() => TokenValue(''), throwsFormatException);
        expect(() => TokenValue('has space'), throwsFormatException);
      });
    });

    group('Given a valid token string,', () {
      test('when passed to the TokenValue constructor, '
          'then the original casing is preserved on the value field.', () {
        expect(TokenValue('GZIP').value, equals('GZIP'));
        expect(TokenValue('X-Foo').value, equals('X-Foo'));
      });

      test('when toString is called, '
          'then it returns the wire value.', () {
        expect(TokenValue('gzip').toString(), equals('gzip'));
        expect(TokenValue('X-Foo').toString(), equals('X-Foo'));
      });
    });
  });

  group('TokenValue equality and hashing', () {
    group('Given two TokenValues differing only in ASCII letter case,', () {
      test('when compared with ==, '
          'then they are equal.', () {
        expect(TokenValue('gzip') == TokenValue('GZIP'), isTrue);
      });

      test('when their hashCodes are compared, '
          'then they are equal.', () {
        expect(
          TokenValue('gzip').hashCode,
          equals(TokenValue('GZIP').hashCode),
        );
      });

      test('when placed into a Set, '
          'then the Set treats them as one element.', () {
        final set = <TokenValue>{
          TokenValue('gzip'),
          TokenValue('GZIP'),
          TokenValue('deflate'),
        };

        expect(set, hasLength(2));
        expect(set.contains(TokenValue('gZiP')), isTrue);
      });
    });

    group('Given two TokenValues with different wire values,', () {
      test('when compared with ==, '
          'then they are not equal.', () {
        expect(TokenValue('gzip') == TokenValue('deflate'), isFalse);
      });
    });

    group('Given a TokenValue and another Token of equal value,', () {
      test('when compared with ==, '
          'then they are not equal.', () {
        final tv = TokenValue('foo');
        final other = _EnumLikeToken('foo');

        // ignore: unrelated_type_equality_checks
        expect(tv == other, isFalse);
      });

      test('when compared with Token.equals, '
          'then they are reported equal by wire value.', () {
        final tv = TokenValue('foo');
        final other = _EnumLikeToken('foo');

        expect(Token.equals(tv, other), isTrue);
      });
    });
  });
}

/// Stands in for an enum value that `implements Token` with identity equality.
class _EnumLikeToken implements Token {
  @override
  final String value;
  const _EnumLikeToken(this.value);
}
