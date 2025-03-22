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
    skip: 'drop strict mode',
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
            () async => await getServerRequestHeaders(
              server: server,
              headers: {'content-location': ''},
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
        'when a Content-Location header with an invalid URI is passed then the '
        'server responds with a bad request including a message that states the '
        'URI is invalid',
        () async {
          expect(
            () async => await getServerRequestHeaders(
              server: server,
              headers: {'content-location': 'ht!tp://invalid-url'},
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
        'when a Content-Location header with an invalid port is passed then the '
        'server responds with a bad request including a message that states the '
        'URI is invalid',
        () async {
          expect(
            () async => await getServerRequestHeaders(
              server: server,
              headers: {'content-location': 'https://example.com:test'},
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
        'when a Content-Location header with an invalid value is passed '
        'then the server does not respond with a bad request if the headers '
        'is not actually used',
        () async {
          var headers = await getServerRequestHeaders(
            server: server,
            headers: {'content-location': 'https://example.com:test'},
            eagerParseHeaders: false,
          );

          expect(headers, isNotNull);
        },
      );

      test(
        'when a Content-Location header with a valid URI is passed then it '
        'should parse correctly',
        () async {
          var headers = await getServerRequestHeaders(
            server: server,
            headers: {'content-location': 'https://example.com/resource'},
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
          var headers = await getServerRequestHeaders(
            server: server,
            headers: {'content-location': 'https://example.com:8080'},
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
          var headers = await getServerRequestHeaders(
            server: server,
            headers: {},
          );

          expect(headers.contentLocation_.valueOrNullIfInvalid, isNull);
          expect(() => headers.contentLocation,
              throwsA(isA<InvalidHeaderException>()));
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
          var headers = await getServerRequestHeaders(
            server: server,
            headers: {'content-location': 'ht!tp://invalid-url'},
          );

          expect(headers.contentLocation_.valueOrNullIfInvalid, isNull);
          expect(() => headers.contentLocation,
              throwsA(isA<InvalidHeaderException>()));
        },
      );

      test(
        'then it should be recorded in the "failedHeadersToParse" field',
        skip: 'todo: drop failedHeadersToParse',
        () async {
          var headers = await getServerRequestHeaders(
            server: server,
            headers: {'content-location': 'ht!tp://invalid-url'},
          );

          expect(
            headers.failedHeadersToParse['content-location'],
            equals(['ht!tp://invalid-url']),
          );
        },
      );
    });
  });
}
