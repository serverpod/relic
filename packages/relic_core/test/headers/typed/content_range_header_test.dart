import 'package:relic_core/relic_core.dart';
import 'package:test/test.dart';

void main() {
  group('ContentRangeHeader construction invariants', () {
    group('Given start set but end null,', () {
      test('when constructed, '
          'then it throws a FormatException.', () {
        expect(
          () => ContentRangeHeader(start: 0, end: null, size: 100),
          throwsFormatException,
        );
      });
    });

    group('Given end set but start null,', () {
      test('when constructed, '
          'then it throws a FormatException.', () {
        expect(
          () => ContentRangeHeader(start: null, end: 99, size: 100),
          throwsFormatException,
        );
      });
    });

    group('Given start, end, and size all null,', () {
      test('when constructed, '
          'then it throws a FormatException.', () {
        expect(
          () => ContentRangeHeader(start: null, end: null, size: null),
          throwsFormatException,
        );
      });
    });

    group('Given start > end,', () {
      test('when constructed, '
          'then it throws a FormatException.', () {
        expect(
          () => ContentRangeHeader(start: 100, end: 50, size: 1000),
          throwsFormatException,
        );
      });
    });

    group('Given the unsatisfied-range form (no range, size set),', () {
      test('when constructed and encoded, '
          'then the wire form is "unit */size".', () {
        final h = ContentRangeHeader(size: 1234);

        expect(h.toString(), contains('start: null'));
        expect(ContentRangeHeader.codec.encode(h), equals(['bytes */1234']));
      });
    });

    group('Given a satisfied range,', () {
      test('when encoded, '
          'then the wire form is "unit start-end/size".', () {
        final h = ContentRangeHeader(start: 0, end: 499, size: 1234);

        expect(
          ContentRangeHeader.codec.encode(h),
          equals(['bytes 0-499/1234']),
        );
      });

      test('when encoded with unknown total size, '
          'then size renders as "*".', () {
        final h = ContentRangeHeader(start: 0, end: 499);

        expect(ContentRangeHeader.codec.encode(h), equals(['bytes 0-499/*']));
      });
    });
  });

  group('ContentRangeHeader.parse', () {
    group('Given a satisfied byte range with known size,', () {
      test('when parsed, '
          'then start, end, and size are populated.', () {
        final h = ContentRangeHeader.parse('bytes 0-499/1234');

        expect(h.unit, equals('bytes'));
        expect(h.start, equals(0));
        expect(h.end, equals(499));
        expect(h.size, equals(1234));
      });
    });

    group('Given an unsatisfied range with known size,', () {
      test('when parsed, '
          'then start and end are null and size is set.', () {
        final h = ContentRangeHeader.parse('bytes */1234');

        expect(h.start, isNull);
        expect(h.end, isNull);
        expect(h.size, equals(1234));
      });
    });

    group('Given a "bytes */*" header,', () {
      test('when parsed, '
          'then it throws because the unsatisfied form requires a length.', () {
        expect(
          () => ContentRangeHeader.parse('bytes */*'),
          throwsFormatException,
        );
      });
    });

    group('Given a valid range followed by trailing garbage,', () {
      test('when parsed, '
          'then it throws instead of silently dropping the tail.', () {
        expect(
          () => ContentRangeHeader.parse('bytes 0-499/1234 evil'),
          throwsFormatException,
        );
      });
    });

    group('Given leading garbage before a valid range,', () {
      test('when parsed, '
          'then it throws.', () {
        expect(
          () => ContentRangeHeader.parse('x bytes 0-499/1234'),
          throwsFormatException,
        );
      });
    });

    group('Given a numeric field too large to represent,', () {
      test('when parsed, '
          'then it throws instead of silently becoming unsatisfied.', () {
        expect(
          () => ContentRangeHeader.parse(
            'bytes 99999999999999999999-99999999999999999999/100',
          ),
          throwsFormatException,
        );
        expect(
          () => ContentRangeHeader.parse('bytes 0-10/99999999999999999999'),
          throwsFormatException,
        );
      });
    });
  });
}
