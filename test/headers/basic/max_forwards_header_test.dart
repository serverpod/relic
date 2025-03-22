import 'package:relic/relic.dart';
import 'package:test/test.dart';
import 'package:relic/src/headers/standard_headers_extensions.dart';

import '../headers_test_utils.dart';
import '../docs/strict_validation_docs.dart';

/// Reference: https://developer.mozilla.org/en-US/docs/Web/HTTP/Headers/Max-Forwards
/// About empty value test, check the [StrictValidationDocs] class for more details.
void main() {
  group(
    'Given a Max-Forwards header with the strict flag true',
    skip: 'drop strict mode',
    () {
      late RelicServer server;

      setUp(() async {
        server = await createServer(strictHeaders: true);
      });

      tearDown(() => server.close());

      test(
        'when an empty Max-Forwards header is passed then the server responds '
        'with a bad request including a message that states the header value '
        'cannot be empty',
        () async {
          expect(
            () async => await getServerRequestHeaders(
              server: server,
              headers: {'max-forwards': ''},
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
        'when a Max-Forwards header with a negative number is passed then the server '
        'responds with a bad request including a message that states the value '
        'must be non-negative',
        () async {
          expect(
            () async => await getServerRequestHeaders(
              server: server,
              headers: {'max-forwards': '-1'},
            ),
            throwsA(
              isA<BadRequestException>().having(
                (e) => e.message,
                'message',
                contains('Must be non-negative'),
              ),
            ),
          );
        },
      );

      test(
        'when a Max-Forwards header with a non-integer value is passed then the server '
        'responds with a bad request including a message that states the value '
        'must be an integer',
        () async {
          expect(
            () async => await getServerRequestHeaders(
              server: server,
              headers: {'max-forwards': '5.5'},
            ),
            throwsA(
              isA<BadRequestException>().having(
                (e) => e.message,
                'message',
                contains('Must be an integer'),
              ),
            ),
          );
        },
      );

      test(
        'when a Max-Forwards header with an invalid value is passed '
        'then the server does not respond with a bad request if the headers '
        'is not actually used',
        () async {
          var headers = await getServerRequestHeaders(
            server: server,
            headers: {'max-forwards': 'invalid-value'},
            eagerParseHeaders: false,
          );

          expect(headers, isNotNull);
        },
      );

      test(
        'when a Max-Forwards header with a valid integer is passed then it '
        'should parse correctly',
        () async {
          var headers = await getServerRequestHeaders(
            server: server,
            headers: {'max-forwards': '5'},
          );

          expect(headers.maxForwards, equals(5));
        },
      );

      test(
        'when a Max-Forwards header with zero is passed then it should parse correctly',
        () async {
          var headers = await getServerRequestHeaders(
            server: server,
            headers: {'max-forwards': '0'},
          );

          expect(headers.maxForwards, equals(0));
        },
      );

      test(
        'when no Max-Forwards header is passed then it should return null',
        () async {
          var headers = await getServerRequestHeaders(
            server: server,
            headers: {},
          );

          expect(headers.maxForwards_.valueOrNullIfInvalid, isNull);
          expect(() => headers.maxForwards,
              throwsA(isA<InvalidHeaderException>()));
        },
      );
    },
  );

  group('Given a Max-Forwards header with the strict flag false', () {
    late RelicServer server;

    setUp(() async {
      server = await createServer(strictHeaders: false);
    });

    tearDown(() => server.close());

    group('when an invalid Max-Forwards header is passed', () {
      test(
        'then it should return null',
        () async {
          var headers = await getServerRequestHeaders(
            server: server,
            headers: {'max-forwards': 'invalid'},
          );

          expect(headers.maxForwards_.valueOrNullIfInvalid, isNull);
          expect(() => headers.maxForwards,
              throwsA(isA<InvalidHeaderException>()));
        },
      );

      test(' then it should be recorded in "failedHeadersToParse" field',
          () async {
        var headers = await getServerRequestHeaders(
          server: server,
          headers: {'max-forwards': 'invalid'},
        );

        expect(
          headers.failedHeadersToParse['max-forwards'],
          equals(['invalid']),
        );
      }, skip: 'drop failedHeadersToParse');
    });
  });
}
