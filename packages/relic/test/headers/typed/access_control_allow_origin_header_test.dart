import 'package:relic/relic.dart';
import 'package:test/test.dart';

import '../docs/strict_validation_docs.dart';
import '../headers_test_utils.dart';

/// Reference: https://developer.mozilla.org/en-US/docs/Web/HTTP/Headers/Access-Control-Allow-Origin
/// For more details on header validation behavior, see the [HeaderValidationDocs] class.
void main() {
  group('Given an Access-Control-Allow-Origin header with validation', () {
    late RelicServer server;

    setUp(() async {
      server = await createServer();
    });

    tearDown(() => server.close());

    test(
      'when an empty Access-Control-Allow-Origin header is passed then the server responds '
      'with a bad request including a message that states the header value '
      'cannot be empty',
      () async {
        expect(
          getServerRequestHeaders(
            server: server,
            touchHeaders: (final h) => h.accessControlAllowOrigin,
            headers: {'access-control-allow-origin': ''},
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
      'when a Access-Control-Allow-Origin header with an invalid URI is passed '
      'then the server responds with a bad request including a message that '
      'states the URI is invalid',
      () async {
        expect(
          getServerRequestHeaders(
            server: server,
            touchHeaders: (final h) => h.accessControlAllowOrigin,
            headers: {'access-control-allow-origin': 'ht!tp://invalid-url'},
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
      'when an Access-Control-Allow-Origin header with an invalid port is passed '
      'then the server responds with a bad request including a message that '
      'states the URI is invalid',
      () async {
        expect(
          getServerRequestHeaders(
            server: server,
            touchHeaders: (final h) => h.accessControlAllowOrigin,
            headers: {
              'access-control-allow-origin': 'https://example.com:test',
            },
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
      'when a Access-Control-Allow-Origin header with an invalid value is passed '
      'then the server does not respond with a bad request if the headers '
      'is not actually used',
      () async {
        final headers = await getServerRequestHeaders(
          server: server,
          touchHeaders: (_) {},
          headers: {'access-control-allow-origin': 'https://example.com:test'},
        );

        expect(headers, isNotNull);
      },
    );

    test(
      'when a Access-Control-Allow-Origin header with a valid URI origin is passed '
      'then it should parse correctly',
      () async {
        final headers = await getServerRequestHeaders(
          server: server,
          touchHeaders: (final h) => h.accessControlAllowOrigin,
          headers: {'access-control-allow-origin': 'https://example.com'},
        );

        expect(
          headers.accessControlAllowOrigin?.origin,
          equals(Uri.parse('https://example.com')),
        );
      },
    );

    test(
      'when a Access-Control-Allow-Origin header with a valid URI origin and port is passed '
      'then it should parse correctly',
      () async {
        final headers = await getServerRequestHeaders(
          server: server,
          touchHeaders: (final h) => h.accessControlAllowOrigin,
          headers: {'access-control-allow-origin': 'https://example.com:8080'},
        );

        expect(headers.accessControlAllowOrigin?.origin?.port, equals(8080));
      },
    );

    test(
      'when a Access-Control-Allow-Origin header with a valid URI origin with '
      'spaces is passed then it should parse correctly',
      () async {
        final headers = await getServerRequestHeaders(
          server: server,
          touchHeaders: (final h) => h.accessControlAllowOrigin,
          headers: {'access-control-allow-origin': ' https://example.com '},
        );

        expect(
          headers.accessControlAllowOrigin?.origin,
          equals(Uri.parse('https://example.com')),
        );
      },
    );

    test(
      'when a Access-Control-Allow-Origin header with a wildcard (*) is passed '
      'then it should parse correctly',
      () async {
        final headers = await getServerRequestHeaders(
          server: server,
          touchHeaders: (final h) => h.accessControlAllowOrigin,
          headers: {'access-control-allow-origin': '*'},
        );

        expect(headers.accessControlAllowOrigin?.isWildcard, isTrue);
        expect(headers.accessControlAllowOrigin?.origin, isNull);
      },
    );

    test(
      'when no Access-Control-Allow-Origin header is passed then it should return null',
      () async {
        final headers = await getServerRequestHeaders(
          server: server,
          touchHeaders: (final h) => h.accessControlAllowOrigin,
          headers: {},
        );

        expect(headers.accessControlAllowOrigin, isNull);
      },
    );
  });

  group('Given an Access-Control-Allow-Origin header without validation', () {
    late RelicServer server;

    setUp(() async {
      server = await createServer();
    });

    tearDown(() => server.close());

    group('When an invalid Access-Control-Allow-Origin header is passed', () {
      test('then it should return null', () async {
        final headers = await getServerRequestHeaders(
          server: server,
          touchHeaders: (_) {},
          headers: {'access-control-allow-origin': 'ht!tp://invalid-url'},
        );

        expect(
          Headers.accessControlAllowOrigin[headers].valueOrNullIfInvalid,
          isNull,
        );
        expect(() => headers.accessControlAllowOrigin, throwsInvalidHeader);
      });
    });
  });
}
