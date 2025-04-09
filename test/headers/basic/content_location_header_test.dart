import 'package:relic/relic.dart';
import 'package:relic/src/headers/standard_headers_extensions.dart';
import 'package:test/test.dart';

import '../docs/strict_validation_docs.dart';
import '../headers_test_utils.dart';

/// Reference: https://developer.mozilla.org/en-US/docs/Web/HTTP/Headers/Content-Location
/// About empty value test, check the [StrictValidationDocs] class for more details.
void main() {
  group(
    'Given a Content-Location header with the strict flag true',
    () {
      late RelicServer server;

      setUp(() async {
        server = await createServer(strictHeaders: true);
      });

      tearDown(() => server.close());

      test(
        'when an empty Content-Location header is passed then the server responds '
        'with a bad request including a message that states the header value '
        'cannot be empty',
        () async {
          expect(
            getServerRequestHeaders(
              server: server,
              headers: {'content-location': ''},
              touchHeaders: (final h) => h.contentLocation,
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
        'when a Content-Location header with an invalid URI is passed then the '
        'server responds with a bad request including a message that states the '
        'URI is invalid',
        () async {
          expect(
            getServerRequestHeaders(
              server: server,
              headers: {'content-location': 'ht!tp://invalid-url'},
              touchHeaders: (final h) => h.contentLocation,
            ),
            throwsA(
              isA<BadRequestException>().having(
                (final e) => e.message,
                'message',
                contains('Invalid URI format'),
              ),
            ),
          );
        },
      );

      test(
        'when a Content-Location header with an invalid port is passed then the '
        'server responds with a bad request including a message that states the '
        'URI is invalid',
        () async {
          expect(
            getServerRequestHeaders(
              server: server,
              headers: {'content-location': 'https://example.com:test'},
              touchHeaders: (final h) => h.contentLocation,
            ),
            throwsA(
              isA<BadRequestException>().having(
                (final e) => e.message,
                'message',
                contains('Invalid URI format'),
              ),
            ),
          );
        },
      );

      test(
        'when a Content-Location header with an invalid value is passed '
        'then the server does not respond with a bad request if the headers '
        'is not actually used',
        () async {
          final headers = await getServerRequestHeaders(
            server: server,
            touchHeaders: (final _) {},
            headers: {'content-location': 'https://example.com:test'},
          );

          expect(headers, isNotNull);
        },
      );

      test(
        'when a Content-Location header with a valid URI is passed then it '
        'should parse correctly',
        () async {
          final headers = await getServerRequestHeaders(
            server: server,
            headers: {'content-location': 'https://example.com/resource'},
            touchHeaders: (final h) => h.contentLocation,
          );

          expect(
            headers.contentLocation,
            equals(Uri.parse('https://example.com/resource')),
          );
        },
      );

      test(
        'when a Content-Location header with a valid URI and port is passed then '
        'it should parse correctly',
        () async {
          final headers = await getServerRequestHeaders(
            server: server,
            headers: {'content-location': 'https://example.com:8080'},
            touchHeaders: (final h) => h.contentLocation,
          );

          expect(
            headers.contentLocation?.port,
            equals(8080),
          );
        },
      );

      test(
        'when no Content-Location header is passed then it should return null',
        () async {
          final headers = await getServerRequestHeaders(
            server: server,
            headers: {},
            touchHeaders: (final h) => h.contentLocation,
          );

          expect(headers.contentLocation, isNull);
        },
      );
    },
  );

  group('Given a Content-Location header with the strict flag false', () {
    late RelicServer server;

    setUp(() async {
      server = await createServer(strictHeaders: false);
    });

    tearDown(() => server.close());

    group('when an invalid Content-Location header is passed', () {
      test(
        'then it should return null',
        () async {
          final headers = await getServerRequestHeaders(
            server: server,
            touchHeaders: (final _) {},
            headers: {'content-location': 'ht!tp://invalid-url'},
          );

          expect(Headers.contentLocation[headers].valueOrNullIfInvalid, isNull);
          expect(() => headers.contentLocation, throwsInvalidHeader);
        },
      );
    });
  });
}
