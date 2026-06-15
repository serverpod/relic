import 'package:relic_core/relic_core.dart';
import 'package:test/test.dart';

void main() {
  group('AcceptRangesHeader.parse', () {
    group('Given a list of range units,', () {
      test('when parsed, '
          'then all units are preserved (lowercased).', () {
        final h = AcceptRangesHeader.parse('bytes, Custom-Unit');

        expect(h.rangeUnits, equals(['bytes', 'custom-unit']));
        expect(h.isBytes, isTrue);
      });
    });

    group('Given the none sentinel alone,', () {
      test('when parsed, '
          'then isNone is true.', () {
        expect(AcceptRangesHeader.parse('none').isNone, isTrue);
      });
    });

    group('Given none combined with another unit,', () {
      test('when parsed, '
          'then it throws (none is the exclusive no-support sentinel).', () {
        expect(
          () => AcceptRangesHeader.parse('bytes, none'),
          throwsFormatException,
        );
      });
    });
  });
}
