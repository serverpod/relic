import 'package:relic/relic.dart';
import 'package:test/test.dart';

import '../docs/strict_validation_docs.dart';
import '../headers_test_utils.dart';

/// Reference: https://developer.mozilla.org/en-US/docs/Web/HTTP/Headers/Access-Control-Allow-Headers
/// About empty value test, check the [StrictValidationDocs] class for more details.
void main() {
  group(
      'Given an Access-Control-Allow-Headers header with the strict flag true',
      () {
    late RelicServer server;

    setUp(() async {
      server = await createServer(strictHeaders: true);
    });

    tearDown(() => server.close());

    test(
      'when an empty Access-Control-Allow-Headers header is passed then '
      'the server should respond with a bad request including a message '
      'that states the value cannot be empty',
      () async {
        expect(
          getServerRequestHeaders(
            server: server,
            touchHeaders: (final h) => h.accessControlAllowHeaders,
            headers: {'access-control-allow-headers': ''},
          ),
          throwsA(isA<BadRequestException>().having(
            (final e) => e.message,
            'message',
            contains('Value cannot be empty'),
          )),
        );
      },
    );

    test(
      'when an Access-Control-Allow-Headers header with a wildcard (*) '
      'is passed then the server should respond with a bad request including '
      'a message that states the wildcard cannot be used with other headers',
      () async {
        expect(
          getServerRequestHeaders(
            server: server,
            touchHeaders: (final h) => h.accessControlAllowHeaders,
            headers: {'access-control-allow-headers': '*, Content-Type'},
          ),
          throwsA(isA<BadRequestException>().having(
            (final e) => e.message,
            'message',
            contains('Wildcard (*) cannot be used with other values'),
          )),
        );
      },
    );

    test(
      'when a Access-Control-Allow-Headers header with an invalid value is passed '
      'then the server does not respond with a bad request if the headers '
      'is not actually used',
      () async {
        final headers = await getServerRequestHeaders(
          server: server,
          touchHeaders: (final _) {},
          headers: {'access-control-allow-headers': '*, Content-Type'},
        );

        expect(headers, isNotNull);
      },
    );

    test(
      'when a valid Access-Control-Allow-Headers header is passed then it should parse the headers correctly',
      () async {
        final headers = await getServerRequestHeaders(
          server: server,
          touchHeaders: (final _) {},
          headers: {
            'access-control-allow-headers': 'Content-Type, X-Custom-Header'
          },
        );

        final allowedHeaders = headers.accessControlAllowHeaders?.headers;
        expect(allowedHeaders?.length, equals(2));
        expect(
          allowedHeaders,
          containsAll(['Content-Type', 'X-Custom-Header']),
        );
      },
    );

    test(
      'when an Access-Control-Allow-Headers header with wildcard is passed then it should parse correctly',
      () async {
        final headers = await getServerRequestHeaders(
          server: server,
          touchHeaders: (final h) => h.accessControlAllowHeaders,
          headers: {'access-control-allow-headers': '*'},
        );

        expect(headers.accessControlAllowHeaders?.isWildcard, isTrue);
      },
    );

    test(
      'when no Access-Control-Allow-Headers header is passed then it should return null',
      () async {
        final headers = await getServerRequestHeaders(
          server: server,
          touchHeaders: (final h) => h.accessControlAllowHeaders,
          headers: {},
        );

        expect(headers.accessControlAllowHeaders, isNull);
      },
    );
  });

  group(
      'Given an Access-Control-Allow-Headers header with the strict flag false',
      () {
    late RelicServer server;

    setUp(() async {
      server = await createServer(strictHeaders: false);
    });

    tearDown(() => server.close());

    group('when an empty Access-Control-Allow-Headers header is passed', () {
      test('then it should return null', () async {
        final headers = await getServerRequestHeaders(
          server: server,
          touchHeaders: (final _) {},
          headers: {},
        );
        expect(headers.accessControlAllowHeaders, isNull);
      });
    });
  });
}
