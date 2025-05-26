import 'package:relic/relic.dart';
import 'package:test/test.dart';

import '../docs/strict_validation_docs.dart';
import '../headers_test_utils.dart';

/// About empty value test, check the [StrictValidationDocs] class for more details.
void main() {
  group(
    'Given an X-Powered-By header with the strict flag true',
    () {
      late RelicServer server;

      setUp(() async {
        server = await createServer(strictHeaders: true);
      });

      tearDown(() => server.close());

      test(
          'when an empty X-Powered-By header is passed then the server responds '
          'with a bad request including a message that states the header value '
          'cannot be empty', () async {
        expect(
          getServerRequestHeaders(
              server: server,
              headers: {'x-powered-by': ''},
              touchHeaders: (final h) => h.xPoweredBy),
          throwsA(
            isA<BadRequestException>().having(
              (final e) => e.message,
              'message',
              contains('Value cannot be empty'),
            ),
          ),
        );
      });

      test(
        'when a valid X-Powered-By value is passed then it should parse correctly',
        () async {
          final headers = await getServerRequestHeaders(
            server: server,
            headers: {'x-powered-by': 'Express'},
            touchHeaders: (final h) => h.xPoweredBy,
          );

          expect(headers.xPoweredBy, equals('Express'));
        },
      );
    },
  );

  group(
    'Given an X-Powered-By header with the strict flag false',
    skip: 'x-powered-by is a response header (stripped on get request)',
    () {
      late RelicServer server;

      setUp(() async {
        server = await createServer(strictHeaders: false);
      });

      tearDown(() => server.close());
    },
  );
}
