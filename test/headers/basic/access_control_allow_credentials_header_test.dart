import 'package:relic/relic.dart';
import 'package:relic/src/headers/standard_headers_extensions.dart';
import 'package:test/test.dart';

import '../docs/strict_validation_docs.dart';
import '../headers_test_utils.dart';

/// Reference: https://developer.mozilla.org/en-US/docs/Web/HTTP/Headers/Access-Control-Allow-Credentials
/// These tests verify the behavior of the Access-Control-Allow-Credentials header.
/// According to the CORS specification, this header can only have the value "true".
/// It indicates whether the response to the request can be exposed when the credentials flag is true.
/// The tests cover both strict and non-strict modes, ensuring that invalid values are handled appropriately.
/// Reference: https://developer.mozilla.org/en-US/docs/Web/HTTP/Headers/Access-Control-Allow-Credentials#directives
/// About empty value test, check the [StrictValidationDocs] class for more details.

void main() {
  group(
    'Given an Access-Control-Allow-Credentials header with the strict flag true',
    () {
      late RelicServer server;

      setUp(() async {
        server = await createServer(strictHeaders: true);
      });

      tearDown(() => server.close());

      test(
        'when an empty Access-Control-Allow-Credentials header is passed then the server responds '
        'with a bad request including a message that states the header value '
        'cannot be empty',
        () async {
          expect(
            () async => await getServerRequestHeaders(
              server: server,
              headers: {'access-control-allow-credentials': ''},
              touchHeaders: (h) => h.accessControlAllowCredentials,
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
        'when an invalid Access-Control-Allow-Credentials header is passed then the server responds '
        'with a bad request including a message that states the header value is invalid',
        () async {
          expect(
            () async => await getServerRequestHeaders(
              server: server,
              headers: {'access-control-allow-credentials': 'blabla'},
              touchHeaders: (h) => h.accessControlAllowCredentials,
            ),
            throwsA(
              isA<BadRequestException>().having(
                (e) => e.message,
                'message',
                contains('Invalid boolean'),
              ),
            ),
          );
        },
      );

      test(
        'when a Access-Control-Allow-Credentials header with a value "false" '
        'then the server responds with a bad request including a message that states the header value '
        'must be "true" or "null"',
        () async {
          expect(
            () async => await getServerRequestHeaders(
              server: server,
              headers: {'access-control-allow-credentials': 'false'},
              touchHeaders: (h) => h.accessControlAllowCredentials,
            ),
            throwsA(
              isA<BadRequestException>().having(
                (e) => e.message,
                'message',
                contains('Must be true or null'),
              ),
            ),
          );
        },
      );

      test(
        'when a Access-Control-Allow-Credentials header with an invalid value is passed '
        'then the server does not respond with a bad request if the headers '
        'is not actually used',
        () async {
          var headers = await getServerRequestHeaders(
            server: server,
            touchHeaders: (_) {},
            headers: {'access-control-allow-credentials': 'test'},
          );

          expect(headers, isNotNull);
        },
      );

      test(
        'when a Access-Control-Allow-Credentials header with a value "true" '
        'is passed then it should parse correctly',
        () async {
          var headers = await getServerRequestHeaders(
            server: server,
            headers: {'access-control-allow-credentials': 'true'},
            touchHeaders: (h) => h.accessControlAllowCredentials,
          );

          expect(headers.accessControlAllowCredentials, isTrue);
        },
      );

      test(
        'when no Access-Control-Allow-Credentials header is passed then it should return null',
        () async {
          var headers = await getServerRequestHeaders(
            server: server,
            headers: {},
            touchHeaders: (h) => h.accessControlAllowCredentials,
          );

          expect(headers.accessControlAllowCredentials, isNull);
        },
      );
    },
  );

  group(
      'Given an Access-Control-Allow-Credentials header with the strict flag false',
      () {
    late RelicServer server;

    setUp(() async {
      server = await createServer(strictHeaders: false);
    });

    tearDown(() => server.close());

    group('when an empty Access-Control-Allow-Credentials header is passed',
        () {
      test(
        'then it should return null',
        () async {
          var headers = await getServerRequestHeaders(
            server: server,
            touchHeaders: (_) {},
            headers: {'access-control-allow-credentials': ''},
          );

          final header = Headers.accessControlAllowCredentials[headers];
          expect(header.valueOrNullIfInvalid, isNull);
          expect(() => header.valueOrNull, throwsInvalidHeader);
          expect(() => header.value, throwsInvalidHeader);
        },
      );
    });
  });
}
