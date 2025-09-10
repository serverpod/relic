import 'package:relic/relic.dart';
import 'package:test/test.dart';

import '../docs/strict_validation_docs.dart';

/// About empty value test, check the [StrictValidationDocs] class for more details.
void main() {
  group(
    'Given an X-Powered-By header accessor',
    () {
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
    },
  );
}
