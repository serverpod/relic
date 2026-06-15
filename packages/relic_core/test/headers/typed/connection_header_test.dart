import 'package:relic_core/relic_core.dart';
import 'package:test/test.dart';

void main() {
  group('ConnectionHeader.parse', () {
    group('Given an empty value,', () {
      test('when parsed, '
          'then it throws a FormatException.', () {
        expect(() => ConnectionHeader.parse(['']), throwsFormatException);
      });
    });

    group('Given a non-token connection-option,', () {
      test('when parsed, '
          'then it throws (RFC 9110 7.6.1 connection-option is a token).', () {
        expect(
          () => ConnectionHeader.parse(['bad directive']),
          throwsFormatException,
        );
      });
    });

    group('Given a valid multi-directive value,', () {
      test('when parsed, '
          'then the directives are preserved and lowercased.', () {
        final header = ConnectionHeader.parse(['keep-alive, Upgrade']);

        expect(
          header.directives.map((final d) => d.value),
          equals(['keep-alive', 'upgrade']),
        );
      });
    });

    group('Given an unknown but valid connection-option,', () {
      test('when parsed, '
          'then it is accepted (open token set).', () {
        final header = ConnectionHeader.parse(['TE']);

        expect(header.directives.single.value, equals('te'));
      });
    });

    group('Given duplicate directives,', () {
      test('when parsed, '
          'then exact duplicates are removed.', () {
        final header = ConnectionHeader.parse([
          'keep-alive, upgrade, keep-alive',
        ]);

        expect(
          header.directives.map((final d) => d.value),
          equals(['keep-alive', 'upgrade']),
        );
      });
    });
  });
}
