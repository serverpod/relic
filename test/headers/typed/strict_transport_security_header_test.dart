import 'package:relic/relic.dart';
import 'package:test/test.dart';

import '../docs/strict_validation_docs.dart';
import '../headers_test_utils.dart';

/// Reference: https://developer.mozilla.org/en-US/docs/Web/HTTP/Headers/Strict-Transport-Security
/// For more details on header validation behavior, see the [HeaderValidationDocs] class.
void main() {
  group(
    'Given a Strict-Transport-Security header with validation',
    () {
      late RelicServer server;

      setUp(() async {
        server = await createServer();
      });

      tearDown(() => server.close());

      test(
        'when an empty Strict-Transport-Security header is passed then the server should respond with a bad request '
        'including a message that states the value cannot be empty',
        () async {
          expect(
            getServerRequestHeaders(
              server: server,
              touchHeaders: (final h) => h.strictTransportSecurity,
              headers: {'strict-transport-security': ''},
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
        'when a Strict-Transport-Security header with invalid max-age is passed '
        'then the server should respond with a bad request including a message '
        'that states the max-age directive is missing or invalid',
        () async {
          expect(
            getServerRequestHeaders(
              server: server,
              touchHeaders: (final h) => h.strictTransportSecurity,
              headers: {'strict-transport-security': 'max-age=abc'},
            ),
            throwsA(isA<BadRequestException>().having(
              (final e) => e.message,
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
              touchHeaders: (final h) => h.strictTransportSecurity,
              headers: {'strict-transport-security': 'includeSubDomains'},
            ),
            throwsA(isA<BadRequestException>().having(
              (final e) => e.message,
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
          final headers = await getServerRequestHeaders(
            server: server,
            touchHeaders: (final _) {},
            headers: {'strict-transport-security': 'max-age=abc'},
          );

          expect(headers, isNotNull);
        },
      );

      test(
        'when a valid Strict-Transport-Security header is passed then it should parse the directives correctly',
        () async {
          final headers = await getServerRequestHeaders(
            server: server,
            touchHeaders: (final _) {},
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
          final headers = await getServerRequestHeaders(
            server: server,
            touchHeaders: (final h) => h.strictTransportSecurity,
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
          final headers = await getServerRequestHeaders(
            server: server,
            touchHeaders: (final h) => h.strictTransportSecurity,
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
          final headers = await getServerRequestHeaders(
            server: server,
            touchHeaders: (final h) => h.strictTransportSecurity,
            headers: {},
          );

          expect(headers.strictTransportSecurity, isNull);
        },
      );
    },
  );

  group('Given a Strict-Transport-Security header without validation', () {
    late RelicServer server;

    setUp(() async {
      server = await createServer();
    });

    tearDown(() => server.close());

    group('when an empty Strict-Transport-Security header is passed', () {
      test(
        'then it should return null',
        () async {
          final headers = await getServerRequestHeaders(
            server: server,
            touchHeaders: (final _) {},
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
