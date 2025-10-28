import 'package:http_parser/http_parser.dart';
import 'package:relic/relic.dart';
import 'package:test/test.dart';

import '../docs/strict_validation_docs.dart';
import '../headers_test_utils.dart';

/// Reference: https://developer.mozilla.org/en-US/docs/Web/HTTP/Headers/If-Unmodified-Since
/// For more details on header validation behavior, see the [HeaderValidationDocs] class.
void main() {
  group('Given an If-Unmodified-Since header with validation', () {
    late RelicServer server;

    setUp(() async {
      server = await createServer();
    });

    tearDown(() => server.close());

    test(
      'when an empty If-Unmodified-Since header is passed then the server responds '
      'with a bad request including a message that states the header value '
      'cannot be empty',
      () async {
        expect(
          getServerRequestHeaders(
            server: server,
            headers: {'if-unmodified-since': ''},
            touchHeaders: (final h) => h.ifUnmodifiedSince,
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
      'when an If-Unmodified-Since header with an invalid date format is passed '
      'then the server responds with a bad request including a message that '
      'states the date format is invalid',
      () async {
        expect(
          getServerRequestHeaders(
            server: server,
            headers: {'if-unmodified-since': 'invalid-date-format'},
            touchHeaders: (final h) => h.ifUnmodifiedSince,
          ),
          throwsA(
            isA<BadRequestException>().having(
              (final e) => e.message,
              'message',
              contains('Invalid date format'),
            ),
          ),
        );
      },
    );

    test(
      'when an If-Unmodified-Since header with an invalid date format is passed '
      'then the server does not respond with a bad request if the headers '
      'is not actually used',
      () async {
        final headers = await getServerRequestHeaders(
          server: server,
          touchHeaders: (_) {},
          headers: {'if-unmodified-since': 'invalid-date-format'},
        );

        expect(headers, isNotNull);
      },
    );

    test(
      'when a valid If-Unmodified-Since header is passed then it should parse the '
      'date correctly',
      () async {
        final headers = await getServerRequestHeaders(
          server: server,
          headers: {'if-unmodified-since': 'Wed, 21 Oct 2015 07:28:00 GMT'},
          touchHeaders: (final h) => h.ifUnmodifiedSince,
        );

        expect(
          headers.ifUnmodifiedSince,
          equals(parseHttpDate('Wed, 21 Oct 2015 07:28:00 GMT')),
        );
      },
    );

    test(
      'when an If-Unmodified-Since header with extra whitespace is passed then it should parse the date correctly',
      () async {
        final headers = await getServerRequestHeaders(
          server: server,
          headers: {'if-unmodified-since': ' Wed, 21 Oct 2015 07:28:00 GMT '},
          touchHeaders: (final h) => h.ifUnmodifiedSince,
        );

        expect(
          headers.ifUnmodifiedSince,
          equals(parseHttpDate('Wed, 21 Oct 2015 07:28:00 GMT')),
        );
      },
    );

    test(
      'when no If-Unmodified-Since header is passed then it should return null',
      () async {
        final headers = await getServerRequestHeaders(
          server: server,
          headers: {},
          touchHeaders: (final h) => h.ifUnmodifiedSince,
        );

        expect(headers.ifUnmodifiedSince, isNull);
      },
    );
  });

  group('Given an If-Unmodified-Since header without validation', () {
    late RelicServer server;

    setUp(() async {
      server = await createServer();
    });

    tearDown(() => server.close());

    group('when an empty If-Unmodified-Since header is passed', () {
      test('then it should return null', () async {
        final headers = await getServerRequestHeaders(
          server: server,
          touchHeaders: (_) {},
          headers: {'if-unmodified-since': ''},
        );

        expect(Headers.ifUnmodifiedSince[headers].valueOrNullIfInvalid, isNull);
        expect(() => headers.ifUnmodifiedSince, throwsInvalidHeader);
      });
    });

    group('when an invalid If-Unmodified-Since header is passed', () {
      test('then it should return null', () async {
        final headers = await getServerRequestHeaders(
          server: server,
          touchHeaders: (_) {},
          headers: {'if-unmodified-since': 'invalid-date-format'},
        );

        expect(Headers.ifUnmodifiedSince[headers].valueOrNullIfInvalid, isNull);
        expect(() => headers.ifUnmodifiedSince, throwsInvalidHeader);
      });
    });
  });
}
