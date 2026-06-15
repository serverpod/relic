import 'package:relic_core/relic_core.dart';
import 'package:test/test.dart';

void main() {
  group('ExpectHeader.parse', () {
    group('Given the standard 100-continue value,', () {
      test('when parsed (any case), '
          'then it returns the continue100 constant.', () {
        expect(
          ExpectHeader.parse('100-continue'),
          same(ExpectHeader.continue100),
        );
        expect(
          ExpectHeader.parse('100-Continue'),
          same(ExpectHeader.continue100),
        );
      });
    });

    group('Given an unknown expectation,', () {
      test('when parsed, '
          'then the value is preserved so a server can answer 417.', () {
        expect(
          ExpectHeader.parse('custom-directive').value,
          equals('custom-directive'),
        );
      });
    });

    group('Given a value containing a control character,', () {
      test('when parsed, '
          'then it throws to prevent header injection.', () {
        expect(
          () => ExpectHeader.parse('100-continue\r\nX-Injected: yes'),
          throwsFormatException,
        );
      });
    });

    group('Given an unknown expectation containing a HTAB,', () {
      test('when parsed, '
          'then it is accepted (HTAB is legal OWS).', () {
        expect(ExpectHeader.parse('foo\tbar').value, equals('foo\tbar'));
      });
    });
  });
}
