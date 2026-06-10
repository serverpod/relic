import 'package:relic_core/src/headers/typed/headers/util/qvalue.dart';
import 'package:test/test.dart';

void main() {
  group('formatQValue', () {
    group('Given a value with up to 3 significant digits,', () {
      test('when formatted, '
          'then trailing zeros are stripped.', () {
        expect(formatQValue(0.5), equals('0.5'));
        expect(formatQValue(0.8), equals('0.8'));
        expect(formatQValue(0.333), equals('0.333'));
      });
    });

    group('Given a value just under 1.0,', () {
      test('when formatted, '
          'then it truncates to 0.999 rather than rounding up to 1.', () {
        expect(formatQValue(0.9999), equals('0.999'));
      });
    });

    group('Given a value with more than 3 fractional digits,', () {
      test('when formatted, '
          'then it truncates toward zero to 3 digits.', () {
        expect(formatQValue(0.3335), equals('0.333'));
      });
    });

    group('Given a value extremely close to but below 1.0,', () {
      test('when formatted, '
          'then it truncates to 0.999 rather than rounding up to 1.', () {
        expect(formatQValue(0.99996), equals('0.999'));
        expect(formatQValue(0.999999), equals('0.999'));
      });
    });

    group('Given a small value with a single significant millis digit,', () {
      test('when formatted, '
          'then leading zeros are kept.', () {
        expect(formatQValue(0.005), equals('0.005'));
        expect(formatQValue(0.05), equals('0.05'));
        expect(formatQValue(0.001), equals('0.001'));
      });
    });

    group('Given the bounds,', () {
      test('when formatted, '
          'then 0 and 1 render without a fraction.', () {
        expect(formatQValue(0), equals('0'));
        expect(formatQValue(1), equals('1'));
      });
    });
  });
}
