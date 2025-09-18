import 'package:relic/relic.dart';
import 'package:test/test.dart';

import '../../static/test_util.dart';
import '../docs/strict_validation_docs.dart';
import '../headers_test_utils.dart';

/// About empty value test, check the [StrictValidationDocs] class for more details.
void main() {
  group(
    'Given an X-Powered-By header accessor',
    () {
      late RelicServer server;

      setUp(() async {
        server = await createServer();
      });

      tearDown(() => server.close());

      test(
        'when setting a valid X-Powered-By value then it should be accessible',
        () {
          final headers = Headers.build((final h) {
            h.xPoweredBy = 'Express';
          });

          expect(headers.xPoweredBy, equals('Express'));
        },
      );

      test(
        'when setting X-Powered-By to null then it should be null',
        () {
          final headers = Headers.build((final h) {
            h.xPoweredBy = null;
          });

          expect(headers.xPoweredBy, isNull);
        },
      );

      test(
        'when creating response with X-Powered-By header then it should be preserved',
        () {
          final response = Response.ok(headers: Headers.build((final h) {
            h.xPoweredBy = 'Custom Framework';
          }));

          expect(response.headers.xPoweredBy, equals('Custom Framework'));
        },
      );

      test(
          'when creating response without X-Powered-By header then it should be null',
          () {
        final response = Response.ok();
        expect(response.headers.xPoweredBy, isNull);
      });
    },
  );
}
