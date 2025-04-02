import 'package:relic/relic.dart';
import 'package:test/test.dart';
import 'package:relic/src/headers/standard_headers_extensions.dart';

import '../headers_test_utils.dart';
import '../docs/strict_validation_docs.dart';

/// Reference: https://developer.mozilla.org/en-US/docs/Web/HTTP/Headers/Location
/// About empty value test, check the [StrictValidationDocs] class for more details.
void main() {
  group(
    'Given a Location header with the strict flag true',
    () {
      late RelicServer server;

      setUp(() async {
        server = await createServer(strictHeaders: true);
      });

      tearDown(() => server.close());

      test(
        'when an empty Location header is passed then the server responds '
        'with a bad request including a message that states the header value '
        'cannot be empty',
        () async {
          expect(
            getServerRequestHeaders(
              server: server,
              headers: {'location': ''},
              touchHeaders: (h) => h.location,
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
        'when a Location header with an invalid URI is passed then the server '
        'responds with a bad request including a message that states the URI '
        'is invalid',
        () async {
          expect(
            getServerRequestHeaders(
              server: server,
              headers: {'location': 'ht!tp://invalid-url'},
              touchHeaders: (h) => h.location,
            ),
            throwsA(
              isA<BadRequestException>().having(
                (e) => e.message,
                'message',
                contains('Invalid URI'),
              ),
            ),
          );
        },
      );

      test(
        'when a Location header with an invalid port is passed then the server '
        'responds with a bad request including a message that states the URI '
        'format is invalid',
        () async {
          expect(
            getServerRequestHeaders(
              server: server,
              headers: {'location': 'https://example.com:test'},
              touchHeaders: (h) => h.location,
            ),
            throwsA(
              isA<BadRequestException>().having(
                (e) => e.message,
                'message',
                contains('Invalid URI format'),
              ),
            ),
          );
        },
      );

      test(
        'when a Location header with an invalid value is passed '
        'then the server does not respond with a bad request if the headers '
        'is not actually used',
        () async {
          var headers = await getServerRequestHeaders(
            server: server,
            touchHeaders: (_) {},
            headers: {'location': 'https://example.com:test'},
          );

          expect(headers, isNotNull);
        },
      );

      test(
        'when a Location header with a valid URI is passed then it should parse correctly',
        () async {
          var headers = await getServerRequestHeaders(
            server: server,
            headers: {'location': 'https://example.com/page'},
            touchHeaders: (h) => h.location,
          );

          expect(
            headers.location,
            equals(Uri.parse('https://example.com/page')),
          );
        },
      );

      test(
        'when a Location header with a valid port is passed then it should parse '
        'correctly',
        () async {
          var headers = await getServerRequestHeaders(
            server: server,
            headers: {'location': 'https://example.com:8080'},
            touchHeaders: (h) => h.location,
          );

          expect(
            headers.location?.port,
            equals(8080),
          );
        },
      );

      test(
        'when a Location header with extra whitespace is passed then it should '
        'parse the URI correctly',
        () async {
          var headers = await getServerRequestHeaders(
            server: server,
            headers: {'location': ' https://example.com '},
            touchHeaders: (h) => h.location,
          );

          expect(headers.location, equals(Uri.parse('https://example.com')));
        },
      );

      test(
        'when no Location header is passed then it should return null',
        () async {
          var headers = await getServerRequestHeaders(
            server: server,
            headers: {},
            touchHeaders: (h) => h.location,
          );

          expect(headers.location, isNull);
        },
      );
    },
  );

  group('Given a Location header with the strict flag false', () {
    late RelicServer server;

    setUp(() async {
      server = await createServer(strictHeaders: false);
    });

    tearDown(() => server.close());

    group('when an invalid Location header is passed', () {
      test(
        'then it should return null',
        () async {
          var headers = await getServerRequestHeaders(
            server: server,
            touchHeaders: (_) {},
            headers: {'location': 'ht!tp://invalid-url'},
          );

          expect(Headers.location[headers].valueOrNullIfInvalid, isNull);
          expect(() => headers.location, throwsInvalidHeader);
        },
      );
    });
  });
}
