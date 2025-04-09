import 'package:relic/relic.dart';
import 'package:relic/src/headers/standard_headers_extensions.dart';
import 'package:test/test.dart';

import '../docs/strict_validation_docs.dart';
import '../headers_test_utils.dart';

/// Reference: https://developer.mozilla.org/en-US/docs/Web/HTTP/Headers/If-None-Match
/// About empty value test, check the [StrictValidationDocs] class for more details.
void main() {
  group('Given an If-None-Match header with the strict flag true', () {
    late RelicServer server;

    setUp(() async {
      server = await createServer(strictHeaders: true);
    });

    tearDown(() => server.close());

    test(
      'when an empty If-None-Match header is passed then the server responds '
      'with a bad request including a message that states the header value '
      'cannot be empty',
      () async {
        expect(
          getServerRequestHeaders(
            server: server,
            touchHeaders: (final h) => h.ifNoneMatch,
            headers: {'if-none-match': ''},
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
      'when an If-None-Match header with an invalid ETag is passed then the server '
      'responds with a bad request including a message that states the ETag is invalid',
      () async {
        expect(
          getServerRequestHeaders(
            server: server,
            touchHeaders: (final h) => h.ifNoneMatch,
            headers: {'if-none-match': 'invalid-etag'},
          ),
          throwsA(
            isA<BadRequestException>().having(
              (final e) => e.message,
              'message',
              contains('Invalid ETag format'),
            ),
          ),
        );
      },
    );

    test(
      'when an If-None-Match header with a wildcard (*) and a valid ETag is passed then '
      'the server responds with a bad request including a message that states '
      'the wildcard (*) cannot be used with other values',
      () async {
        expect(
          getServerRequestHeaders(
            server: server,
            touchHeaders: (final h) => h.ifNoneMatch,
            headers: {'if-none-match': '*, 123456"'},
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
      'when an If-None-Match header with an invalid value is passed '
      'then the server does not respond with a bad request if the headers '
      'is not actually used',
      () async {
        final headers = await getServerRequestHeaders(
          server: server,
          touchHeaders: (final _) {},
          headers: {'if-none-match': 'invalid-etag'},
        );

        expect(headers, isNotNull);
      },
    );

    test(
      'when an If-None-Match header with a single valid ETag is passed then it '
      'should parse correctly',
      () async {
        final headers = await getServerRequestHeaders(
          server: server,
          touchHeaders: (final h) => h.ifNoneMatch,
          headers: {'if-none-match': '"123456"'},
        );

        expect(headers.ifNoneMatch?.etags.length, equals(1));
        expect(headers.ifNoneMatch?.etags.first.value, equals('123456'));
        expect(headers.ifNoneMatch?.etags.first.isWeak, isFalse);
      },
    );

    test(
      'when an If-None-Match header with a wildcard (*) is passed then it '
      'should parse correctly',
      () async {
        final headers = await getServerRequestHeaders(
          server: server,
          touchHeaders: (final h) => h.ifNoneMatch,
          headers: {'if-none-match': '*'},
        );

        expect(headers.ifNoneMatch?.isWildcard, isTrue);
        expect(headers.ifNoneMatch?.etags, isEmpty);
      },
    );

    test(
      'when no If-None-Match header is passed then it should default to null',
      () async {
        final headers = await getServerRequestHeaders(
          server: server,
          touchHeaders: (final h) => h.ifNoneMatch,
          headers: {},
        );

        expect(headers.ifNoneMatch, isNull);
      },
    );

    group('when multiple ETags are passed', () {
      test(
        'then they should parse correctly',
        () async {
          final headers = await getServerRequestHeaders(
            server: server,
            touchHeaders: (final h) => h.ifNoneMatch,
            headers: {'if-none-match': '"123", "456", "789"'},
          );

          expect(headers.ifNoneMatch?.etags.length, equals(3));
          expect(
            headers.ifNoneMatch?.etags.map((final e) => e.value).toList(),
            equals(['123', '456', '789']),
          );
        },
      );

      test(
        'with W/ weak validator prefix should be accepted',
        () async {
          final headers = await getServerRequestHeaders(
            server: server,
            touchHeaders: (final h) => h.ifNoneMatch,
            headers: {'if-none-match': 'W/"123", W/"456"'},
          );

          expect(headers.ifNoneMatch?.etags.length, equals(2));
          expect(
            headers.ifNoneMatch?.etags.every((final e) => e.isWeak),
            isTrue,
          );
        },
      );

      test(
        'with extra whitespace are passed then they should parse correctly',
        () async {
          final headers = await getServerRequestHeaders(
            server: server,
            touchHeaders: (final h) => h.ifNoneMatch,
            headers: {'if-none-match': ' "123" , "456" , "789" '},
          );

          expect(headers.ifNoneMatch?.etags.length, equals(3));
          expect(
            headers.ifNoneMatch?.etags.map((final e) => e.value).toList(),
            equals(['123', '456', '789']),
          );
        },
      );

      test(
        'with duplicate values are passed then they should parse correctly '
        'and remove duplicates',
        () async {
          final headers = await getServerRequestHeaders(
            server: server,
            touchHeaders: (final h) => h.ifNoneMatch,
            headers: {'if-none-match': '"123", "456", "789", "123"'},
          );

          expect(headers.ifNoneMatch?.etags.length, equals(3));
          expect(
            headers.ifNoneMatch?.etags.map((final e) => e.value).toList(),
            equals(['123', '456', '789']),
          );
        },
      );
    });
  });

  group('Given an If-None-Match header with the strict flag false', () {
    late RelicServer server;

    setUp(() async {
      server = await createServer(strictHeaders: false);
    });

    tearDown(() => server.close());

    group('when an invalid If-None-Match header is passed', () {
      test(
        'then it should return null',
        () async {
          final headers = await getServerRequestHeaders(
            server: server,
            touchHeaders: (final _) {},
            headers: {'if-none-match': 'invalid-etag'},
          );

          expect(Headers.ifNoneMatch[headers].valueOrNullIfInvalid, isNull);
          expect(() => headers.ifNoneMatch, throwsInvalidHeader);
        },
      );
    });
  });
}
