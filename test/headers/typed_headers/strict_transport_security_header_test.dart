import 'package:relic/relic.dart';
import 'package:test/test.dart';
import 'package:relic/src/headers/standard_headers_extensions.dart';

import '../headers_test_utils.dart';
import '../docs/strict_validation_docs.dart';

/// Reference: https://developer.mozilla.org/en-US/docs/Web/HTTP/Headers/Strict-Transport-Security
/// About empty value test, check the [StrictValidationDocs] class for more details.
void main() {
  group(
    'Given a Strict-Transport-Security header with the strict flag true',
    () {
      late RelicServer server;

      setUp(() async {
        server = await createServer(strictHeaders: true);
      });

      tearDown(() => server.close());

      test(
        'when an empty Strict-Transport-Security header is passed then the server should respond with a bad request '
        'including a message that states the value cannot be empty',
        () async {
          expect(
            getServerRequestHeaders(
              server: server,
              touchHeaders: (h) => h.strictTransportSecurity,
              headers: {'strict-transport-security': ''},
            ),
            throwsA(isA<BadRequestException>().having(
              (e) => e.message,
              'message',
              contains('Value cannot be empty'),
            )),
          );
        },
      );

      test(
        'when a Strict-Transport-Security header with invalid max-age is passed '
        'then the server should respond with a bad request including a message '
        'that states the max-age directive is missing or invalid',
        () async {
          expect(
            getServerRequestHeaders(
              server: server,
              touchHeaders: (h) => h.strictTransportSecurity,
              headers: {'strict-transport-security': 'max-age=abc'},
            ),
            throwsA(isA<BadRequestException>().having(
              (e) => e.message,
              'message',
              contains('Max-age directive is missing or invalid'),
            )),
          );
        },
      );

      test(
        'when a Strict-Transport-Security header without max-age is passed then '
        'the server should respond with a bad request including a message that '
        'states the max-age directive is missing or invalid',
        () async {
          expect(
            getServerRequestHeaders(
              server: server,
              touchHeaders: (h) => h.strictTransportSecurity,
              headers: {'strict-transport-security': 'includeSubDomains'},
            ),
            throwsA(isA<BadRequestException>().having(
              (e) => e.message,
              'message',
              contains('Max-age directive is missing or invalid'),
            )),
          );
        },
      );

      test(
        'when a Strict-Transport-Security header with an invalid value is passed '
        'then the server does not respond with a bad request if the headers '
        'is not actually used',
        () async {
          var headers = await getServerRequestHeaders(
            server: server,
            touchHeaders: (_) {},
            headers: {'strict-transport-security': 'max-age=abc'},
          );

          expect(headers, isNotNull);
        },
      );

      test(
        'when a valid Strict-Transport-Security header is passed then it should parse the directives correctly',
        () async {
          var headers = await getServerRequestHeaders(
            server: server,
            touchHeaders: (_) {},
            headers: {
              'strict-transport-security': 'max-age=31536000; includeSubDomains'
            },
          );

          final hsts = headers.strictTransportSecurity;
          expect(hsts?.maxAge, equals(31536000));
          expect(hsts?.includeSubDomains, isTrue);
        },
      );

      test(
        'when a Strict-Transport-Security header without includeSubDomains is passed then it should parse correctly',
        () async {
          var headers = await getServerRequestHeaders(
            server: server,
            touchHeaders: (h) => h.strictTransportSecurity,
            headers: {'strict-transport-security': 'max-age=31536000'},
          );

          final hsts = headers.strictTransportSecurity;
          expect(hsts?.maxAge, equals(31536000));
          expect(hsts?.includeSubDomains, isFalse);
        },
      );

      test(
        'when a Strict-Transport-Security header with preload is passed then it should parse correctly',
        () async {
          var headers = await getServerRequestHeaders(
            server: server,
            touchHeaders: (h) => h.strictTransportSecurity,
            headers: {'strict-transport-security': 'max-age=31536000; preload'},
          );

          final hsts = headers.strictTransportSecurity;
          expect(hsts?.maxAge, equals(31536000));
          expect(hsts?.preload, isTrue);
        },
      );

      test(
        'when no Strict-Transport-Security header is passed then it should return null',
        () async {
          var headers = await getServerRequestHeaders(
            server: server,
            touchHeaders: (h) => h.strictTransportSecurity,
            headers: {},
          );

          expect(headers.strictTransportSecurity, isNull);
        },
      );
    },
  );

  group('Given a Strict-Transport-Security header with the strict flag false',
      () {
    late RelicServer server;

    setUp(() async {
      server = await createServer(strictHeaders: false);
    });

    tearDown(() => server.close());

    group('when an empty Strict-Transport-Security header is passed', () {
      test(
        'then it should return null',
        () async {
          var headers = await getServerRequestHeaders(
            server: server,
            touchHeaders: (_) {},
            headers: {'strict-transport-security': ''},
          );

          expect(Headers.strictTransportSecurity[headers].valueOrNullIfInvalid,
              isNull);
          expect(() => headers.strictTransportSecurity, throwsInvalidHeader);
        },
      );
    });
  });
}
