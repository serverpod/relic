import 'package:relic/relic.dart';
import 'package:test/test.dart';

import '../docs/strict_validation_docs.dart';
import '../headers_test_utils.dart';

/// Reference: https://developer.mozilla.org/en-US/docs/Web/HTTP/Headers/Access-Control-Max-Age
/// For more details on header validation behavior, see the [HeaderValidationDocs] class.
void main() {
  group('Given an Access-Control-Max-Age header with validation', () {
    late RelicServer server;

    setUp(() async {
      server = await createServer();
    });

    tearDown(() => server.close());

    test(
      'when an empty Access-Control-Max-Age header is passed then the server responds '
      'with a bad request including a message that states the header value '
      'cannot be empty',
      () async {
        expect(
          getServerRequestHeaders(
            server: server,
            headers: {'access-control-max-age': ''},
            touchHeaders: (h) => h.accessControlMaxAge,
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
      'when a invalid Access-Control-Max-Age header is passed then the server '
      'responds with a bad request including a message that states the value is invalid',
      () async {
        expect(
          getServerRequestHeaders(
            server: server,
            headers: {'access-control-max-age': 'invalid'},
            touchHeaders: (h) => h.accessControlMaxAge,
          ),
          throwsA(
            isA<BadRequestException>().having(
              (e) => e.message,
              'message',
              contains('Invalid number'),
            ),
          ),
        );
      },
    );

    test('when a Access-Control-Max-Age header with an invalid value is passed '
        'then the server does not respond with a bad request if the headers '
        'is not actually used', () async {
      final headers = await getServerRequestHeaders(
        server: server,
        touchHeaders: (_) {},
        headers: {'access-control-max-age': 'test'},
      );

      expect(headers, isNotNull);
    });

    test(
      'when a Access-Control-Max-Age header is passed then it should parse the value correctly',
      () async {
        final headers = await getServerRequestHeaders(
          server: server,
          headers: {'access-control-max-age': '600'},
          touchHeaders: (h) => h.accessControlMaxAge,
        );

        expect(headers.accessControlMaxAge, equals(600));
      },
    );

    test(
      'when a Access-Control-Max-Age header with extra whitespace is passed then it should parse the value correctly',
      () async {
        final headers = await getServerRequestHeaders(
          server: server,
          headers: {'access-control-max-age': ' 600 '},
          touchHeaders: (h) => h.accessControlMaxAge,
        );

        expect(headers.accessControlMaxAge, equals(600));
      },
    );

    test(
      'when no Access-Control-Max-Age header is passed then it should return null',
      () async {
        final headers = await getServerRequestHeaders(
          server: server,
          headers: {},
          touchHeaders: (h) => h.accessControlMaxAge,
        );

        expect(headers.accessControlMaxAge, isNull);
      },
    );
  });

  group('Given an Access-Control-Max-Age header '
      'when an invalid raw header is passed', () {
    final headers = Headers.fromMap({
      'access-control-max-age': ['invalid'],
    });

    test('then tryGet returns null and call and get throw', () {
      expect(headers.tryGet(Headers.accessControlMaxAge), isNull);
      expect(() => headers(Headers.accessControlMaxAge), throwsInvalidHeader);
      expect(
        () => headers.get(Headers.accessControlMaxAge),
        throwsInvalidHeader,
      );
    });
  });
}
