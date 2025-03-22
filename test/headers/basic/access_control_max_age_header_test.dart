import 'package:relic/relic.dart';
import 'package:relic/src/headers/standard_headers_extensions.dart';
import 'package:test/test.dart';

import '../docs/strict_validation_docs.dart';
import '../headers_test_utils.dart';

/// Reference: https://developer.mozilla.org/en-US/docs/Web/HTTP/Headers/Access-Control-Max-Age
/// About empty value test, check the [StrictValidationDocs] class for more details.
void main() {
  group(
    'Given an Access-Control-Max-Age header with the strict flag true',
    skip: 'todo: drop strict mode',
    () {
      late RelicServer server;

      setUp(() async {
        server = await createServer(strictHeaders: true);
      });

      tearDown(() => server.close());

      test(
        'when an empty Access-Control-Max-Age header is passed then the server responds '
        'with a bad request including a message that states the header value '
        'cannot be empty',
        () async {
          expect(
            () async => await getServerRequestHeaders(
              server: server,
              headers: {'access-control-max-age': ''},
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
            () async => await getServerRequestHeaders(
              server: server,
              headers: {'access-control-max-age': 'invalid'},
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

      test(
        'when a Access-Control-Max-Age header with an invalid value is passed '
        'then the server does not respond with a bad request if the headers '
        'is not actually used',
        () async {
          var headers = await getServerRequestHeaders(
            server: server,
            headers: {'access-control-max-age': 'test'},
            eagerParseHeaders: false,
          );

          expect(headers, isNotNull);
        },
      );

      test(
        'when a Access-Control-Max-Age header is passed then it should parse the value correctly',
        () async {
          var headers = await getServerRequestHeaders(
            server: server,
            headers: {'access-control-max-age': '600'},
          );

          expect(headers.accessControlMaxAge, equals(600));
        },
      );

      test(
        'when a Access-Control-Max-Age header with extra whitespace is passed then it should parse the value correctly',
        () async {
          var headers = await getServerRequestHeaders(
            server: server,
            headers: {'access-control-max-age': ' 600 '},
          );

          expect(headers.accessControlMaxAge, equals(600));
        },
      );

      test(
        'when no Access-Control-Max-Age header is passed then it should return null',
        () async {
          var headers = await getServerRequestHeaders(
            server: server,
            headers: {},
          );

          expect(headers.accessControlMaxAge_.valueOrNullIfInvalid, isNull);
          expect(() => headers.accessControlMaxAge,
              throwsA(isA<InvalidHeaderException>()));
        },
      );
    },
  );

  group('Given an Access-Control-Max-Age header with the strict flag false',
      () {
    late RelicServer server;

    setUp(() async {
      server = await createServer(strictHeaders: false);
    });

    tearDown(() => server.close());

    group('when an invalid Access-Control-Max-Age header is passed', () {
      test(
        'then it should return null',
        () async {
          var headers = await getServerRequestHeaders(
            server: server,
            headers: {'access-control-max-age': 'invalid'},
          );

          expect(headers.accessControlMaxAge_.valueOrNullIfInvalid, isNull);
          expect(() => headers.accessControlMaxAge_.value,
              throwsA(isA<InvalidHeaderException>()));
        },
      );

      test(
        'then it should be recorded in the "failedHeadersToParse" field',
        skip: 'todo: drop failedHeadersToParse',
        () async {
          var headers = await getServerRequestHeaders(
            server: server,
            headers: {'access-control-max-age': 'invalid'},
          );

          expect(
            headers.failedHeadersToParse['access-control-max-age'],
            equals(['invalid']),
          );
        },
      );
    });
  });
}
