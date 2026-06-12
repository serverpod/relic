import 'package:relic_core/relic_core.dart';
import 'package:test/test.dart';

void main() {
  group('FromHeader.parse', () {
    group('Given a plain addr-spec,', () {
      test('when parsed, '
          'then it is the mailbox.', () {
        expect(
          FromHeader.parse('user@example.com').mailbox,
          equals('user@example.com'),
        );
      });
    });

    group('Given a name-addr with a comma in the display-name,', () {
      test(
        'when parsed, '
        'then it is kept intact (a single mailbox, not split on the comma).',
        () {
          final from = FromHeader.parse('"Doe, John" <john@example.com>');

          expect(from.mailbox, equals('"Doe, John" <john@example.com>'));
        },
      );
    });

    group('Given surrounding whitespace,', () {
      test('when parsed, '
          'then the mailbox is trimmed.', () {
        expect(FromHeader.parse('  a@b  ').mailbox, equals('a@b'));
      });
    });

    group('Given an empty value,', () {
      test('when parsed, '
          'then it throws a FormatException.', () {
        expect(() => FromHeader.parse(''), throwsFormatException);
      });
    });
  });
}
