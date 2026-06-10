import 'package:relic_core/relic_core.dart';
import 'package:test/test.dart';

void main() {
  group('Range construction', () {
    group('Given a range with start greater than end,', () {
      test('when constructed, '
          'then it is accepted; the consumer decides satisfiability.', () {
        final range = Range(start: 100, end: 50);

        expect(range.start, equals(100));
        expect(range.end, equals(50));
      });
    });

    group('Given a range with start equal to end,', () {
      test('when constructed, '
          'then it is accepted.', () {
        expect(Range(start: 5, end: 5).start, equals(5));
      });
    });

    group('Given an open-ended or suffix range,', () {
      test('when constructed, '
          'then it is accepted.', () {
        expect(Range(start: 100).end, isNull);
        expect(Range(end: 500).start, isNull);
      });
    });
  });

  group('RangeHeader.parse', () {
    group('Given an inverted byte range,', () {
      test('when parsed, '
          'then the bounds are preserved (not rejected).', () {
        final header = RangeHeader.parse('bytes=100-50');

        expect(header.ranges.single.start, equals(100));
        expect(header.ranges.single.end, equals(50));
      });
    });
  });
}
