import 'package:relic/relic.dart';
import 'package:relic/src/headers/standard_headers_extensions.dart';
import 'package:test/test.dart';

import '../docs/strict_validation_docs.dart';
import '../headers_test_utils.dart';

/// Reference: https://developer.mozilla.org/en-US/docs/Web/HTTP/Headers/Cross-Origin-Resource-Policy
/// About empty value test, check the [StrictValidationDocs] class for more details.
void main() {
  group(
    'Given a Cross-Origin-Resource-Policy header with the strict flag true',
    () {
      late RelicServer server;

      setUp(() async {
        server = await createServer(strictHeaders: true);
      });

      tearDown(() => server.close());

      test(
        'when an empty Cross-Origin-Resource-Policy header is passed then the server should respond with a bad request '
        'including a message that states the value cannot be empty',
        () async {
          expect(
            getServerRequestHeaders(
              server: server,
              touchHeaders: (final h) => h.crossOriginResourcePolicy,
              headers: {'cross-origin-resource-policy': ''},
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
        'when an invalid Cross-Origin-Resource-Policy header is passed then the server should respond with a bad request '
        'including a message that states the value is invalid',
        () async {
          expect(
            getServerRequestHeaders(
              server: server,
              touchHeaders: (final h) => h.crossOriginResourcePolicy,
              headers: {'cross-origin-resource-policy': 'custom-policy'},
            ),
            throwsA(isA<BadRequestException>().having(
              (final e) => e.message,
              'message',
              contains('Invalid value'),
            )),
          );
        },
      );

      test(
        'when a Cross-Origin-Resource-Policy header with an invalid value is passed '
        'then the server does not respond with a bad request if the headers '
        'is not actually used',
        () async {
          final headers = await getServerRequestHeaders(
            server: server,
            touchHeaders: (final _) {},
            headers: {'cross-origin-resource-policy': 'custom-policy'},
          );
          expect(headers, isNotNull);
        },
      );

      test(
        'when a valid Cross-Origin-Resource-Policy header is passed then it should parse the policy correctly',
        () async {
          final headers = await getServerRequestHeaders(
            server: server,
            touchHeaders: (final h) => h.crossOriginResourcePolicy,
            headers: {'cross-origin-resource-policy': 'same-origin'},
          );

          expect(
            headers.crossOriginResourcePolicy?.policy,
            equals('same-origin'),
          );
        },
      );

      test(
        'when no Cross-Origin-Resource-Policy header is passed then it should return null',
        () async {
          final headers = await getServerRequestHeaders(
            server: server,
            touchHeaders: (final h) => h.crossOriginResourcePolicy,
            headers: {},
          );

          expect(headers.crossOriginResourcePolicy, isNull);
        },
      );
    },
  );

  group(
    'Given a Cross-Origin-Resource-Policy header with the strict flag false',
    () {
      late RelicServer server;

      setUp(() async {
        server = await createServer(strictHeaders: false);
      });

      tearDown(() => server.close());

      group(
        'When an empty Cross-Origin-Resource-Policy header is passed',
        () {
          test(
            'then it should return null',
            () async {
              final headers = await getServerRequestHeaders(
                server: server,
                touchHeaders: (final _) {},
                headers: {},
              );
              expect(headers.crossOriginResourcePolicy, isNull);
            },
          );
        },
      );
    },
  );
}
