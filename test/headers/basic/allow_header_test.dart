import 'package:relic/relic.dart';
import 'package:test/test.dart';

import '../docs/strict_validation_docs.dart';
import '../headers_test_utils.dart';

/// Reference: https://developer.mozilla.org/en-US/docs/Web/HTTP/Headers/Allow
/// About empty value test, check the [StrictValidationDocs] class for more details.
void main() {
  group(
    'Given an Allow header with the strict flag true',
    () {
      late RelicServer server;

      setUp(() async {
        server = await createServer();
      });

      tearDown(() => server.close());

      test(
        'when an empty Allow header is passed then the server responds '
        'with a bad request including a message that states the header value '
        'cannot be empty',
        () async {
          expect(
            getServerRequestHeaders(
              server: server,
              headers: {'allow': ''},
              touchHeaders: (final h) => h.allow,
            ),
            throwsA(
              isA<BadRequestException>().having(
                (final e) => e.message,
                'message',
                contains('Value cannot be empty'),
              ),
            ),
          );
        },
      );

      test(
        'when an invalid method is passed then the server responds '
        'with a bad request including a message that states the header value '
        'is invalid',
        () async {
          expect(
            getServerRequestHeaders(
              server: server,
              headers: {'allow': 'CUSTOM'},
              touchHeaders: (final h) => h.allow,
            ),
            throwsA(
              isA<BadRequestException>().having(
                (final e) => e.message,
                'message',
                contains('Invalid value'),
              ),
            ),
          );
        },
      );

      test(
        'when an Allow header with an invalid value is passed '
        'then the server does not respond with a bad request if the headers '
        'is not actually used',
        () async {
          final headers = await getServerRequestHeaders(
            server: server,
            touchHeaders: (final _) {},
            headers: {'allow': 'CUSTOM'},
          );

          expect(headers, isNotNull);
        },
      );

      test(
        'when a valid Allow header is passed then it should parse the methods correctly',
        () async {
          final headers = await getServerRequestHeaders(
            server: server,
            headers: {'allow': 'GET, POST, DELETE'},
            touchHeaders: (final h) => h.allow,
          );

          expect(
            headers.allow?.map((final method) => method.value).toList(),
            equals(['GET', 'POST', 'DELETE']),
          );
        },
      );

      test(
        'when an Allow header with duplicate methods is passed then it should '
        'parse the methods correctly and remove duplicates',
        () async {
          final headers = await getServerRequestHeaders(
            server: server,
            headers: {'allow': 'GET, POST, GET'},
            touchHeaders: (final h) => h.allow,
          );

          expect(
            headers.allow?.map((final method) => method.value).toList(),
            equals(['GET', 'POST']),
          );
        },
      );

      test(
        'when an Allow header with spaces is passed then it should parse the '
        'methods correctly',
        () async {
          final headers = await getServerRequestHeaders(
            server: server,
            headers: {'allow': ' GET , POST , DELETE '},
            touchHeaders: (final h) => h.allow,
          );

          expect(
            headers.allow?.map((final method) => method.value).toList(),
            equals(['GET', 'POST', 'DELETE']),
          );
        },
      );
    },
  );

  group('Given an Allow header with the strict flag false', () {
    late RelicServer server;

    setUp(() async {
      server = await createServer();
    });

    tearDown(() => server.close());

    group('when an empty Allow header is passed', () {
      test(
        'then it should return null',
        () async {
          final headers = await getServerRequestHeaders(
            server: server,
            touchHeaders: (final _) {},
            headers: {'allow': ''},
          );

          expect(Headers.allow[headers].valueOrNullIfInvalid, isNull);
        },
      );
    });
  });
}
