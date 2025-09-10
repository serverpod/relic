import 'package:relic/relic.dart';
import 'package:test/test.dart';

import '../docs/strict_validation_docs.dart';
import '../headers_test_utils.dart';

/// Reference: https://developer.mozilla.org/en-US/docs/Web/HTTP/Headers/Access-Control-Request-Headers
/// About empty value test, check the [StrictValidationDocs] class for more details.
void main() {
  group(
    'Given an Access-Control-Request-Headers header with the strict flag true',
    () {
      late RelicServer server;

      setUp(() async {
        server = await createServer();
      });

      tearDown(() => server.close());

      test(
        'when an empty Access-Control-Request-Headers header is passed then the '
        'server responds with a bad request including a message that states the '
        'header value cannot be empty',
        () async {
          expect(
            getServerRequestHeaders(
              server: server,
              headers: {'access-control-request-headers': ''},
              touchHeaders: (final h) => h.accessControlRequestHeaders,
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
        'when an Access-Control-Request-Headers header with an empty value is '
        'passed then the server does not respond with a bad request if the '
        'headers is not actually used',
        () async {
          final headers = await getServerRequestHeaders(
            server: server,
            touchHeaders: (final _) {},
            headers: {'access-control-request-headers': ''},
          );

          expect(headers, isNotNull);
        },
      );

      test(
        'when an Access-Control-Request-Headers header is passed then it '
        'should parse the headers correctly',
        () async {
          final headers = await getServerRequestHeaders(
            server: server,
            headers: {
              'access-control-request-headers':
                  'X-Custom-Header, X-Another-Header'
            },
            touchHeaders: (final h) => h.accessControlRequestHeaders,
          );

          expect(
            headers.accessControlRequestHeaders,
            equals(['X-Custom-Header', 'X-Another-Header']),
          );
        },
      );

      test(
        'when an Access-Control-Request-Headers header with extra whitespace is '
        'passed then it should parse the headers correctly',
        () async {
          final headers = await getServerRequestHeaders(
            server: server,
            headers: {
              'access-control-request-headers':
                  ' X-Custom-Header , X-Another-Header '
            },
            touchHeaders: (final h) => h.accessControlRequestHeaders,
          );

          expect(
            headers.accessControlRequestHeaders,
            equals(['X-Custom-Header', 'X-Another-Header']),
          );
        },
      );

      test(
        'when an Access-Control-Request-Headers header with duplicate headers is '
        'passed then it should parse the headers correctly and remove duplicates',
        () async {
          final headers = await getServerRequestHeaders(
            server: server,
            headers: {
              'access-control-request-headers':
                  'X-Custom-Header, X-Another-Header, X-Custom-Header'
            },
            touchHeaders: (final h) => h.accessControlRequestHeaders,
          );

          expect(
            headers.accessControlRequestHeaders,
            equals(['X-Custom-Header', 'X-Another-Header']),
          );
        },
      );

      test(
        'when no Access-Control-Request-Headers header is passed then it should '
        'default to null',
        () async {
          final headers = await getServerRequestHeaders(
            server: server,
            headers: {},
            touchHeaders: (final h) => h.accessControlRequestHeaders,
          );

          expect(headers.accessControlRequestHeaders, isNull);
        },
      );
    },
  );

  group(
      'Given an Access-Control-Request-Headers header with the strict flag false',
      () {
    late RelicServer server;

    setUp(() async {
      server = await createServer();
    });

    tearDown(() => server.close());

    group('when an empty Access-Control-Request-Headers header is passed', () {
      test(
        'then it should return null',
        () async {
          final headers = await getServerRequestHeaders(
            server: server,
            touchHeaders: (final _) {},
            headers: {'access-control-request-headers': ''},
          );

          expect(
              Headers.accessControlRequestHeaders[headers].valueOrNullIfInvalid,
              isNull);
          expect(
              () => headers.accessControlRequestHeaders, throwsInvalidHeader);
        },
      );
    });
  });
}
