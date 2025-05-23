import 'package:relic/relic.dart';
import 'package:test/test.dart';

import '../docs/strict_validation_docs.dart';
import '../headers_test_utils.dart';

/// Reference: https://developer.mozilla.org/en-US/docs/Web/HTTP/Headers/Range
/// About empty value test, check the [StrictValidationDocs] class for more details.
void main() {
  group('Given a Range header with the strict flag true', () {
    late RelicServer server;

    setUp(() async {
      server = await createServer(strictHeaders: true);
    });

    tearDown(() => server.close());

    test(
      'when a Range header with an empty value is passed then the server '
      'responds with a bad request including a message that states the '
      'header value cannot be empty',
      () async {
        expect(
          getServerRequestHeaders(
            server: server,
            touchHeaders: (final h) => h.range,
            headers: {'range': ''},
          ),
          throwsA(
            isA<BadRequestException>().having(
              (final e) => e.message,
              'message',
              contains('Value cannot be empty'),
            ),
          ),
        );
      },
    );

    test(
      'when a range with invalid format is passed then the server responds with a '
      'bad request including a message that states the range format is invalid',
      () async {
        expect(
          getServerRequestHeaders(
            server: server,
            touchHeaders: (final h) => h.range,
            headers: {'range': 'bytes=abc-xyz'},
          ),
          throwsA(
            isA<BadRequestException>().having(
              (final e) => e.message,
              'message',
              contains('Invalid range'),
            ),
          ),
        );
      },
    );

    test(
      'when a range with both start and end empty is passed then the server responds '
      'with a bad request including a message that states both values cannot be empty',
      () async {
        expect(
          getServerRequestHeaders(
            server: server,
            touchHeaders: (final h) => h.range,
            headers: {'range': 'bytes=-'},
          ),
          throwsA(
            isA<BadRequestException>().having(
              (final e) => e.message,
              'message',
              contains('Both start and end cannot be empty'),
            ),
          ),
        );
      },
    );

    test(
      'when a Range header with an invalid value is passed '
      'then the server does not respond with a bad request if the headers '
      'is not actually used',
      () async {
        final headers = await getServerRequestHeaders(
          server: server,
          touchHeaders: (final _) {},
          headers: {'range': 'invalid-value'},
        );

        expect(headers, isNotNull);
      },
    );

    test(
      'when a Range header with a single valid range is passed then it '
      'should parse correctly',
      () async {
        final headers = await getServerRequestHeaders(
          server: server,
          touchHeaders: (final h) => h.range,
          headers: {'range': 'bytes=0-499'},
        );

        expect(headers.range?.unit, equals('bytes'));
        expect(headers.range?.ranges.length, equals(1));
        expect(headers.range?.ranges.first.start, equals(0));
        expect(headers.range?.ranges.first.end, equals(499));
      },
    );

    test(
      'when a Range header with a range that only has a start is passed then it '
      'should parse correctly',
      () async {
        final headers = await getServerRequestHeaders(
          server: server,
          touchHeaders: (final h) => h.range,
          headers: {'range': 'bytes=500-'},
        );

        expect(headers.range?.unit, equals('bytes'));
        expect(headers.range?.ranges.length, equals(1));
        expect(headers.range?.ranges.first.start, equals(500));
        expect(headers.range?.ranges.first.end, isNull);
      },
    );

    test(
      'when a Range header with a range that only has an end is passed then it '
      'should parse correctly',
      () async {
        final headers = await getServerRequestHeaders(
          server: server,
          touchHeaders: (final h) => h.range,
          headers: {'range': 'bytes=-500'},
        );

        expect(headers.range?.unit, equals('bytes'));
        expect(headers.range?.ranges.length, equals(1));
        expect(headers.range?.ranges.first.start, isNull);
        expect(headers.range?.ranges.first.end, equals(500));
      },
    );

    test(
      'when no Range header is passed then it should return null',
      () async {
        final headers = await getServerRequestHeaders(
          server: server,
          touchHeaders: (final h) => h.range,
          headers: {},
        );

        expect(headers.range, isNull);
      },
    );

    group('when multiple Range headers are passed', () {
      test(
        'then they should parse correctly',
        () async {
          final headers = await getServerRequestHeaders(
            server: server,
            touchHeaders: (final h) => h.range,
            headers: {'range': 'bytes=0-499, 500-999, 1000-'},
          );

          expect(headers.range?.unit, equals('bytes'));
          expect(headers.range?.ranges.length, equals(3));

          final ranges = headers.range!.ranges;
          expect(ranges[0].start, equals(0));
          expect(ranges[0].end, equals(499));
          expect(ranges[1].start, equals(500));
          expect(ranges[1].end, equals(999));
          expect(ranges[2].start, equals(1000));
          expect(ranges[2].end, isNull);
        },
      );

      test(
        'with extra whitespace are passed then they should parse correctly',
        () async {
          final headers = await getServerRequestHeaders(
            server: server,
            touchHeaders: (final h) => h.range,
            headers: {'range': ' bytes = 0-499 , 500-999 , 1000- '},
          );

          expect(headers.range?.ranges.length, equals(3));
          expect(headers.range?.unit, equals('bytes'));
        },
      );
    });
  });

  group('Given a Range header with the strict flag false', () {
    late RelicServer server;

    setUp(() async {
      server = await createServer(strictHeaders: false);
    });

    tearDown(() => server.close());

    group('when an invalid Range header is passed', () {
      test(
        'then it should return null',
        () async {
          final headers = await getServerRequestHeaders(
            server: server,
            touchHeaders: (final _) {},
            headers: {'range': 'invalid-range'},
          );

          expect(Headers.range[headers].valueOrNullIfInvalid, isNull);
          expect(() => headers.range, throwsInvalidHeader);
        },
      );
    });
  });
}
