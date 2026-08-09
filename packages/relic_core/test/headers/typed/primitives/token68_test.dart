import 'package:relic_core/src/headers/typed/primitives/token68.dart';
import 'package:test/test.dart';

void main() {
  group('Token68.isValid', () {
    group('Given a base64 value with trailing padding,', () {
      test('when validated, '
          'then it is accepted.', () {
        expect(Token68.isValid('YWJjZA=='), isTrue);
      });
    });

    group('Given a value using the full token68 alphabet,', () {
      test('when validated, '
          'then it is accepted.', () {
        expect(Token68.isValid('aZ09-._~+/'), isTrue);
        expect(Token68.isValid('a+/b='), isTrue);
      });
    });

    group('Given an empty value,', () {
      test('when validated, '
          'then it is rejected.', () {
        expect(Token68.isValid(''), isFalse);
      });
    });

    group('Given only padding,', () {
      test('when validated, '
          'then it is rejected: token68 requires a leading character.', () {
        expect(Token68.isValid('='), isFalse);
        expect(Token68.isValid('=='), isFalse);
      });
    });

    group('Given a character after the padding,', () {
      test('when validated, '
          'then it is rejected: `=` may only appear as a trailing run.', () {
        expect(Token68.isValid('a=b'), isFalse);
        expect(Token68.isValid('a==b'), isFalse);
      });
    });

    group('Given a character outside the token68 alphabet,', () {
      test('when validated, '
          'then it is rejected.', () {
        expect(Token68.isValid('a b'), isFalse);
        expect(Token68.isValid('a,b'), isFalse);
        expect(Token68.isValid('a"b'), isFalse);
        expect(Token68.isValid('a\r\nb'), isFalse);
      });
    });
  });

  group('Token68.validate', () {
    group('Given a valid value,', () {
      test('when validated, '
          'then it is returned unchanged.', () {
        expect(Token68.validate('YWJjZA=='), equals('YWJjZA=='));
      });
    });

    group('Given an invalid value,', () {
      test('when validated, '
          'then it throws a FormatException.', () {
        expect(() => Token68.validate('a b'), throwsFormatException);
      });
    });
  });
}
