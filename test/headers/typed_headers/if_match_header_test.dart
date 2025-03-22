import 'package:relic/relic.dart';
import 'package:test/test.dart';
import 'package:relic/src/headers/standard_headers_extensions.dart';

import '../headers_test_utils.dart';
import '../docs/strict_validation_docs.dart';

/// Reference: https://developer.mozilla.org/en-US/docs/Web/HTTP/Headers/If-Match
/// About empty value test, check the [StrictValidationDocs] class for more details.
void main() {
  group('Given an If-Match header with the strict flag true',
      skip: 'todo: drop strict mode', () {
    late RelicServer server;

    setUp(() async {
      server = await createServer(strictHeaders: true);
    });

    tearDown(() => server.close());

    test(
      'when an empty If-Match header is passed then the server responds '
      'with a bad request including a message that states the header value '
      'cannot be empty',
      () async {
        expect(
          () async => await getServerRequestHeaders(
            server: server,
            headers: {'if-match': ''},
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
      'when an If-Match header with an invalid ETag is passed then the server '
      'responds with a bad request including a message that states the ETag is invalid',
      () async {
        expect(
          () async => await getServerRequestHeaders(
            server: server,
            headers: {'if-match': 'invalid-etag'},
          ),
          throwsA(
            isA<BadRequestException>().having(
              (e) => e.message,
              'message',
              contains('Invalid ETag format'),
            ),
          ),
        );
      },
    );

    test(
      'when an If-Match header with a wildcard (*) and a valid ETag is passed then '
      'the server responds with a bad request including a message that states '
      'the wildcard (*) cannot be used with other values',
      () async {
        expect(
          () async => await getServerRequestHeaders(
            server: server,
            headers: {'if-match': '*, 123456"'},
          ),
          throwsA(
            isA<BadRequestException>().having(
              (e) => e.message,
              'message',
              contains('Wildcard (*) cannot be used with other values'),
            ),
          ),
        );
      },
    );

    test(
      'when an If-Match header with an invalid value is passed '
      'then the server does not respond with a bad request if the headers '
      'is not actually used',
      () async {
        var headers = await getServerRequestHeaders(
          server: server,
          headers: {'if-match': 'invalid-etag'},
          eagerParseHeaders: false,
        );

        expect(headers, isNotNull);
      },
    );

    test(
      'when an If-Match header with a single valid ETag is passed then it '
      'should parse correctly',
      () async {
        var headers = await getServerRequestHeaders(
          server: server,
          headers: {'if-match': '"123456"'},
        );

        expect(headers.ifMatch?.etags.length, equals(1));
        expect(headers.ifMatch?.etags.first.value, equals('123456'));
        expect(headers.ifMatch?.etags.first.isWeak, isFalse);
      },
    );

    test(
      'when an If-Match header with a wildcard (*) is passed then it '
      'should parse correctly',
      () async {
        var headers = await getServerRequestHeaders(
          server: server,
          headers: {'if-match': '*'},
        );

        expect(headers.ifMatch?.isWildcard, isTrue);
        expect(headers.ifMatch?.etags, isEmpty);
      },
    );

    test(
      'when no If-Match header is passed then it should return null',
      () async {
        var headers = await getServerRequestHeaders(
          server: server,
          headers: {},
        );

        expect(headers.ifMatch_.valueOrNullIfInvalid, isNull);
        expect(() => headers.ifMatch, throwsA(isA<InvalidHeaderException>()));
      },
    );

    group('when multiple ETags are passed', () {
      test(
        'ETags are passed then they should parse correctly',
        () async {
          var headers = await getServerRequestHeaders(
            server: server,
            headers: {'if-match': '"123", "456", "789"'},
          );

          expect(headers.ifMatch?.etags.length, equals(3));
          expect(
            headers.ifMatch?.etags.map((e) => e.value).toList(),
            equals(['123', '456', '789']),
          );
        },
      );

      test(
        'with W/ weak validator prefix should be accepted',
        () async {
          var headers = await getServerRequestHeaders(
            server: server,
            headers: {'if-match': 'W/"123", W/"456"'},
          );

          expect(headers.ifMatch?.etags.length, equals(2));
          expect(
            headers.ifMatch?.etags.every((e) => e.isWeak),
            isTrue,
          );
        },
      );

      test(
        'with extra whitespace are passed then they should parse correctly',
        () async {
          var headers = await getServerRequestHeaders(
            server: server,
            headers: {'if-match': ' "123" , "456" , "789" '},
          );

          expect(headers.ifMatch?.etags.length, equals(3));
          expect(
            headers.ifMatch?.etags.map((e) => e.value).toList(),
            equals(['123', '456', '789']),
          );
        },
      );

      test(
        'with duplicate values are passed then they should parse correctly '
        'and remove duplicates',
        () async {
          var headers = await getServerRequestHeaders(
            server: server,
            headers: {'if-match': '"123", "456", "789", "123"'},
          );

          expect(headers.ifMatch?.etags.length, equals(3));
          expect(
            headers.ifMatch?.etags.map((e) => e.value).toList(),
            equals(['123', '456', '789']),
          );
        },
      );
    });
  });

  group('Given an If-Match header with the strict flag false', () {
    late RelicServer server;

    setUp(() async {
      server = await createServer(strictHeaders: false);
    });

    tearDown(() => server.close());

    group('when an invalid If-Match header is passed', () {
      test(
        'then it should return null',
        () async {
          var headers = await getServerRequestHeaders(
            server: server,
            headers: {'if-match': 'invalid-etag'},
          );

          expect(headers.ifMatch_.valueOrNullIfInvalid, isNull);
          expect(() => headers.ifMatch, throwsA(isA<InvalidHeaderException>()));
        },
      );

      test(
        'then it should be recorded in "failedHeadersToParse" field',
        skip: 'drop failedHeadersToParse',
        () async {
          var headers = await getServerRequestHeaders(
            server: server,
            headers: {'if-match': 'invalid-etag'},
          );

          expect(
            headers.failedHeadersToParse['if-match'],
            equals(['invalid-etag']),
          );
        },
      );
    });
  });
}
