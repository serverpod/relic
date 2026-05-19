import 'package:relic_core/src/headers/typed/primitives/delta_seconds.dart';
import 'package:test/test.dart';

void main() {
  group('DeltaSeconds construction', () {
    group('Given a non-negative int,', () {
      test('when DeltaSeconds is constructed, '
          'then the seconds value is preserved.', () {
        expect(DeltaSeconds(0).seconds, equals(0));
        expect(DeltaSeconds(31536000).seconds, equals(31536000));
      });
    });

    group('Given a negative int,', () {
      test('when DeltaSeconds is constructed, '
          'then it throws a FormatException.', () {
        expect(() => DeltaSeconds(-1), throwsFormatException);
        expect(() => DeltaSeconds(-31536000), throwsFormatException);
      });
    });
  });

  group('DeltaSeconds.parse', () {
    group('Given a digits-only string,', () {
      test('when parsed, '
          'then the resulting seconds match int.parse.', () {
        expect(DeltaSeconds.parse('0').seconds, equals(0));
        expect(DeltaSeconds.parse('31536000').seconds, equals(31536000));
      });
    });

    group('Given an empty string,', () {
      test('when parsed, '
          'then it throws a FormatException.', () {
        expect(() => DeltaSeconds.parse(''), throwsFormatException);
      });
    });

    group('Given a string with a leading sign,', () {
      test('when parsed, '
          'then it throws a FormatException.', () {
        expect(() => DeltaSeconds.parse('+5'), throwsFormatException);
        expect(() => DeltaSeconds.parse('-1'), throwsFormatException);
      });
    });

    group('Given a string with surrounding whitespace,', () {
      test('when parsed, '
          'then it throws a FormatException.', () {
        expect(() => DeltaSeconds.parse(' 5'), throwsFormatException);
        expect(() => DeltaSeconds.parse('5 '), throwsFormatException);
      });
    });

    group('Given a string with non-digit characters,', () {
      test('when parsed, '
          'then it throws a FormatException.', () {
        expect(() => DeltaSeconds.parse('5a'), throwsFormatException);
        expect(() => DeltaSeconds.parse('1.5'), throwsFormatException);
        expect(() => DeltaSeconds.parse('0x10'), throwsFormatException);
      });
    });
  });

  group('DeltaSeconds.encode', () {
    group('Given a DeltaSeconds value,', () {
      test('when encoded, '
          'then the result is the decimal digits of seconds.', () {
        expect(DeltaSeconds(0).encode(), equals('0'));
        expect(DeltaSeconds(60).encode(), equals('60'));
        expect(DeltaSeconds(31536000).encode(), equals('31536000'));
      });

      test('when round-tripped through parse, '
          'then the seconds value is preserved.', () {
        for (final s in const [0, 1, 30, 3600, 86400, 31536000]) {
          expect(
            DeltaSeconds.parse(DeltaSeconds(s).encode()).seconds,
            equals(s),
          );
        }
      });
    });
  });
}
