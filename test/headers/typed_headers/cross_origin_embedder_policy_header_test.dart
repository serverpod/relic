import 'package:relic/relic.dart';
import 'package:test/test.dart';

import '../docs/strict_validation_docs.dart';
import '../headers_test_utils.dart';

/// Reference: https://developer.mozilla.org/en-US/docs/Web/HTTP/Headers/Cross-Origin-Embedder-Policy
/// About empty value test, check the [StrictValidationDocs] class for more details.
void main() {
  group(
    'Given a Cross-Origin-Embedder-Policy header with the strict flag true',
    () {
      late RelicServer server;

      setUp(() async {
        server = await createServer(strictHeaders: true);
      });

      tearDown(() => server.close());

      test(
        'when an empty Cross-Origin-Embedder-Policy header is passed then the server should respond with a bad request '
        'including a message that states the value cannot be empty',
        () async {
          expect(
            getServerRequestHeaders(
              server: server,
              touchHeaders: (final h) => h.crossOriginEmbedderPolicy,
              headers: {'cross-origin-embedder-policy': ''},
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
        'when an invalid Cross-Origin-Embedder-Policy header is passed then the server should respond with a bad request '
        'including a message that states the value is invalid',
        () async {
          expect(
            getServerRequestHeaders(
              server: server,
              touchHeaders: (final h) => h.crossOriginEmbedderPolicy,
              headers: {'cross-origin-embedder-policy': 'custom-policy'},
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
        'when a Cross-Origin-Embedder-Policy header with an invalid value is passed '
        'then the server does not respond with a bad request if the headers '
        'is not actually used',
        () async {
          final headers = await getServerRequestHeaders(
            server: server,
            touchHeaders: (final _) {},
            headers: {'cross-origin-embedder-policy': 'custom-policy'},
          );
          expect(headers, isNotNull);
        },
      );

      test(
        'when a valid Cross-Origin-Embedder-Policy header is passed then it should parse the policy correctly',
        () async {
          final headers = await getServerRequestHeaders(
            server: server,
            touchHeaders: (final h) => h.crossOriginEmbedderPolicy,
            headers: {'cross-origin-embedder-policy': 'require-corp'},
          );

          expect(
            headers.crossOriginEmbedderPolicy?.policy,
            equals('require-corp'),
          );
        },
      );

      test(
        'when no Cross-Origin-Embedder-Policy header is passed then it should return null',
        () async {
          final headers = await getServerRequestHeaders(
            server: server,
            touchHeaders: (final h) => h.crossOriginEmbedderPolicy,
            headers: {},
          );

          expect(headers.crossOriginEmbedderPolicy, isNull);
        },
      );
    },
  );

  group(
    'Given a Cross-Origin-Embedder-Policy header with the strict flag false',
    () {
      late RelicServer server;

      setUp(() async {
        server = await createServer(strictHeaders: false);
      });

      tearDown(() => server.close());

      group('When an empty Cross-Origin-Embedder-Policy header is passed', () {
        test(
          'then it should return null',
          () async {
            final headers = await getServerRequestHeaders(
              server: server,
              touchHeaders: (final _) {},
              headers: {},
            );
            expect(headers.crossOriginEmbedderPolicy, isNull);
          },
        );
      });
    },
  );
}
