import 'package:relic/relic.dart';
import 'package:http_parser/http_parser.dart';
import 'package:relic/src/headers/standard_headers_extensions.dart';
import 'package:test/test.dart';

import '../docs/strict_validation_docs.dart';
import '../headers_test_utils.dart';

/// Reference: https://developer.mozilla.org/en-US/docs/Web/HTTP/Headers/Date
/// About empty value test, check the [StrictValidationDocs] class for more details.
void main() {
  group(
    'Given a Date header with the strict flag true',
    () {
      late RelicServer server;

      setUp(() async {
        server = await createServer(strictHeaders: true);
      });

      tearDown(() => server.close());

      test(
        'when an empty Date header is passed then the server responds '
        'with a bad request including a message that states the header value '
        'cannot be empty',
        () async {
          expect(
            getServerRequestHeaders(
              server: server,
              headers: {'date': ''},
              touchHeaders: (h) => h.date,
            ),
            throwsA(
              isA<BadRequestException>().having(
                (e) => e.message,
                'message',
                contains('Value cannot be empty'),
              ),
            ),
          );
        },
      );

      test(
        'when a Date header with an invalid date format is passed '
        'then the server responds with a bad request including a message that '
        'states the date format is invalid',
        () async {
          expect(
            getServerRequestHeaders(
              server: server,
              headers: {'date': 'invalid-date-format'},
              touchHeaders: (h) => h.date,
            ),
            throwsA(
              isA<BadRequestException>().having(
                (e) => e.message,
                'message',
                contains('Invalid date format'),
              ),
            ),
          );
        },
      );

      test(
        'when a Date header with an invalid date format is passed '
        'then the server does not respond with a bad request if the headers '
        'is not actually used',
        () async {
          var headers = await getServerRequestHeaders(
            server: server,
            touchHeaders: (_) {},
            headers: {'date': 'invalid-date-format'},
          );

          expect(headers, isNotNull);
        },
      );

      test(
        'when a valid Date header is passed then it should parse the date correctly',
        () async {
          var headers = await getServerRequestHeaders(
            server: server,
            headers: {'date': 'Wed, 21 Oct 2015 07:28:00 GMT'},
            touchHeaders: (h) => h.date,
          );

          expect(
            headers.date,
            equals(parseHttpDate('Wed, 21 Oct 2015 07:28:00 GMT')),
          );
        },
      );

      test(
        'when a Date header with extra whitespace is passed then it should parse the date correctly',
        () async {
          var headers = await getServerRequestHeaders(
            server: server,
            headers: {'date': ' Wed, 21 Oct 2015 07:28:00 GMT '},
            touchHeaders: (h) => h.date,
          );

          expect(
            headers.date,
            equals(parseHttpDate('Wed, 21 Oct 2015 07:28:00 GMT')),
          );
        },
      );

      test(
        'when no Date header is passed then it should return null',
        () async {
          var headers = await getServerRequestHeaders(
            server: server,
            headers: {},
            touchHeaders: (h) => h.date,
          );

          expect(headers.date, isNull);
        },
      );
    },
  );

  group('Given a Date header with the strict flag false', () {
    late RelicServer server;

    setUp(() async {
      server = await createServer(strictHeaders: false);
    });

    tearDown(() => server.close());

    group('when an empty Date header is passed', () {
      test(
        'then it should return null',
        () async {
          var headers = await getServerRequestHeaders(
            server: server,
            touchHeaders: (_) {},
            headers: {'date': ''},
          );

          expect(Headers.date[headers].valueOrNullIfInvalid, isNull);
          expect(() => headers.date, throwsInvalidHeader);
        },
      );
    });

    group('when an invalid Date header is passed', () {
      test(
        'then it should return null',
        () async {
          var headers = await getServerRequestHeaders(
            server: server,
            touchHeaders: (_) {},
            headers: {'date': 'invalid-date-format'},
          );

          expect(Headers.date[headers].valueOrNullIfInvalid, isNull);
          expect(() => headers.date, throwsInvalidHeader);
        },
      );
    });
  });
}
