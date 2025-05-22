import 'package:relic/relic.dart';
import 'package:test/test.dart';

import '../docs/strict_validation_docs.dart';
import '../headers_test_utils.dart';

/// Reference: https://developer.mozilla.org/en-US/docs/Web/HTTP/Headers/Access-Control-Expose-Headers
/// About empty value test, check the [StrictValidationDocs] class for more details.
void main() {
  group(
      'Given an Access-Control-Expose-Headers header with the strict flag true',
      () {
    late RelicServer server;

    setUp(() async {
      server = await createServer(strictHeaders: true);
    });

    tearDown(() => server.close());

    test(
      'when an empty Access-Control-Expose-Headers header is passed then the server responds '
      'with a bad request including a message that states the header value '
      'cannot be empty',
      () async {
        expect(
          getServerRequestHeaders(
            server: server,
            touchHeaders: (final h) => h.accessControlExposeHeaders,
            headers: {'access-control-expose-headers': ''},
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
      'when a Access-Control-Expose-Headers header with a wildcard (*) is used '
      'with another header then the server responds '
      'with a bad request including a message that states the wildcard (*) '
      'cannot be used with other values',
      () async {
        expect(
          getServerRequestHeaders(
            server: server,
            touchHeaders: (final h) => h.accessControlExposeHeaders,
            headers: {'access-control-expose-headers': '*, X-Custom-Header'},
          ),
          throwsA(
            isA<BadRequestException>().having(
              (final e) => e.message,
              'message',
              contains('Wildcard (*) cannot be used with other values'),
            ),
          ),
        );
      },
    );

    test(
      'when a Access-Control-Expose-Headers header with an invalid value is passed '
      'then the server does not respond with a bad request if the headers '
      'is not actually used',
      () async {
        final headers = await getServerRequestHeaders(
          server: server,
          touchHeaders: (final _) {},
          headers: {'access-control-expose-headers': '*, X-Custom-Header'},
        );

        expect(headers, isNotNull);
      },
    );

    test(
      'when a Access-Control-Expose-Headers header with a single valid header is '
      'passed then it should parse correctly',
      () async {
        final headers = await getServerRequestHeaders(
          server: server,
          touchHeaders: (final h) => h.accessControlExposeHeaders,
          headers: {'access-control-expose-headers': 'X-Custom-Header'},
        );

        expect(
          headers.accessControlExposeHeaders?.headers,
          equals(['X-Custom-Header']),
        );
      },
    );

    test(
      'when a wildcard (*) is passed then it should parse correctly',
      () async {
        final headers = await getServerRequestHeaders(
          server: server,
          touchHeaders: (final h) => h.accessControlExposeHeaders,
          headers: {'access-control-expose-headers': '*'},
        );

        expect(headers.accessControlExposeHeaders?.isWildcard, isTrue);
        expect(headers.accessControlExposeHeaders?.headers, isNull);
      },
    );

    test(
      'when no Access-Control-Expose-Headers header is passed then it should return null',
      () async {
        final headers = await getServerRequestHeaders(
          server: server,
          touchHeaders: (final h) => h.accessControlExposeHeaders,
          headers: {},
        );

        expect(headers.accessControlExposeHeaders, isNull);
      },
    );

    group('when multiple Access-Control-Expose-Headers headers are passed', () {
      test(
        'then they should parse correctly',
        () async {
          final headers = await getServerRequestHeaders(
            server: server,
            touchHeaders: (final _) {},
            headers: {
              'access-control-expose-headers':
                  'X-Custom-Header, X-Another-Header'
            },
          );

          expect(
            headers.accessControlExposeHeaders?.headers,
            equals(['X-Custom-Header', 'X-Another-Header']),
          );
        },
      );

      test(
        'with extra whitespace then they should parse correctly',
        () async {
          final headers = await getServerRequestHeaders(
            server: server,
            touchHeaders: (final _) {},
            headers: {
              'access-control-expose-headers':
                  ' X-Custom-Header , X-Another-Header '
            },
          );

          expect(
            headers.accessControlExposeHeaders?.headers,
            equals(['X-Custom-Header', 'X-Another-Header']),
          );
        },
      );
    });
  });

  group(
      'Given an Access-Control-Expose-Headers header with the strict flag false',
      () {
    late RelicServer server;

    setUp(() async {
      server = await createServer(strictHeaders: false);
    });

    tearDown(() => server.close());

    group('when an invalid Access-Control-Expose-Headers header is passed', () {
      test(
        'then it should return null',
        () async {
          final headers = await getServerRequestHeaders(
            server: server,
            touchHeaders: (final _) {},
            headers: {'access-control-expose-headers': ''},
          );

          expect(
              Headers.accessControlExposeHeaders[headers].valueOrNullIfInvalid,
              isNull);
          expect(() => headers.accessControlExposeHeaders, throwsInvalidHeader);
        },
      );
    });
  });
}
