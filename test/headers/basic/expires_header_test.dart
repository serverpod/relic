import 'package:http_parser/http_parser.dart';
import 'package:relic/relic.dart';
import 'package:relic/src/headers/standard_headers_extensions.dart';
import 'package:test/test.dart';

import '../docs/strict_validation_docs.dart';
import '../headers_test_utils.dart';

/// Reference: https://developer.mozilla.org/en-US/docs/Web/HTTP/Headers/Expires
/// About empty value test, check the [StrictValidationDocs] class for more details.
void main() {
  group(
    'Given an Expires header with the strict flag true',
    () {
      late RelicServer server;

      setUp(() async {
        server = await createServer(strictHeaders: true);
      });

      tearDown(() => server.close());

      test(
        'when an empty Expires header is passed then the server responds '
        'with a bad request including a message that states the header value '
        'cannot be empty',
        () async {
          expect(
            getServerRequestHeaders(
              server: server,
              headers: {'expires': ''},
              touchHeaders: (final h) => h.expires,
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
        'when an Expires header with an invalid date format is passed '
        'then the server responds with a bad request including a message that '
        'states the date format is invalid',
        () async {
          expect(
            getServerRequestHeaders(
              server: server,
              headers: {'expires': 'invalid-date-format'},
              touchHeaders: (final h) => h.expires,
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
        'when an Expires header with an invalid date format is passed '
        'then the server does not respond with a bad request if the headers '
        'is not actually used',
        () async {
          final headers = await getServerRequestHeaders(
            server: server,
            touchHeaders: (final _) {},
            headers: {'expires': 'invalid-date-format'},
          );

          expect(headers, isNotNull);
        },
      );

      test(
        'when a valid Expires header is passed then it should parse the date correctly',
        () async {
          final headers = await getServerRequestHeaders(
            server: server,
            headers: {'expires': 'Wed, 21 Oct 2015 07:28:00 GMT'},
            touchHeaders: (final h) => h.expires,
          );

          expect(
            headers.expires,
            equals(parseHttpDate('Wed, 21 Oct 2015 07:28:00 GMT')),
          );
        },
      );

      test(
        'when an Expires header with extra whitespace is passed then it should parse the date correctly',
        () async {
          final headers = await getServerRequestHeaders(
            server: server,
            headers: {'expires': ' Wed, 21 Oct 2015 07:28:00 GMT '},
            touchHeaders: (final h) => h.expires,
          );

          expect(
            headers.expires,
            equals(parseHttpDate('Wed, 21 Oct 2015 07:28:00 GMT')),
          );
        },
      );

      test(
        'when no Expires header is passed then it should return null',
        () async {
          final headers = await getServerRequestHeaders(
            server: server,
            headers: {},
            touchHeaders: (final h) => h.expires,
          );

          expect(headers.expires, isNull);
        },
      );
    },
  );

  group('Given an Expires header with the strict flag false', () {
    late RelicServer server;

    setUp(() async {
      server = await createServer(strictHeaders: false);
    });

    tearDown(() => server.close());

    group('when an empty Expires header is passed ', () {
      test(
        'then it should return null',
        () async {
          final headers = await getServerRequestHeaders(
            server: server,
            touchHeaders: (final _) {},
            headers: {'expires': ''},
          );

          expect(Headers.expires[headers].valueOrNullIfInvalid, isNull);
          expect(() => headers.expires, throwsInvalidHeader);
        },
      );
    });

    group('when an invalid Expires header is passed', () {
      test(
        'then it should return null',
        () async {
          final headers = await getServerRequestHeaders(
            server: server,
            touchHeaders: (final _) {},
            headers: {'expires': 'invalid-date-format'},
          );

          expect(Headers.expires[headers].valueOrNullIfInvalid, isNull);
          expect(() => headers.expires, throwsInvalidHeader);
        },
      );
    });
  });
}
