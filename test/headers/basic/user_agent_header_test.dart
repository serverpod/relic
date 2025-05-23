import 'package:relic/relic.dart';
import 'package:test/test.dart';

import '../docs/strict_validation_docs.dart';
import '../headers_test_utils.dart';

/// Reference: https://developer.mozilla.org/en-US/docs/Web/HTTP/Headers/User-Agent
/// About empty value test, check the [StrictValidationDocs] class for more details.
void main() {
  group('Given a User-Agent header with the strict flag true', () {
    late RelicServer server;

    setUp(() async {
      server = await createServer(strictHeaders: true);
    });

    tearDown(() => server.close());

    test(
      'when an empty User-Agent header is passed then the server responds '
      'with a bad request including a message that states the header value '
      'cannot be empty',
      () async {
        expect(
          getServerRequestHeaders(
            server: server,
            headers: {'user-agent': ''},
            touchHeaders: (final h) => h.userAgent,
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
      'when a User-Agent header with an empty value is passed '
      'then the server does not respond with a bad request if the headers '
      'is not actually used',
      () async {
        final headers = await getServerRequestHeaders(
          server: server,
          touchHeaders: (final _) {},
          headers: {'user-agent': ''},
        );

        expect(headers, isNotNull);
      },
    );

    test(
      'when a User-Agent string is passed then it should parse correctly',
      () async {
        final headers = await getServerRequestHeaders(
          server: server,
          headers: {'user-agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64)'},
          touchHeaders: (final h) => h.userAgent,
        );

        expect(
          headers.userAgent,
          equals('Mozilla/5.0 (Windows NT 10.0; Win64; x64)'),
        );
      },
    );

    test(
      'when no User-Agent header is passed then it should default to a non-null value',
      () async {
        final headers = await getServerRequestHeaders(
          server: server,
          headers: {},
          touchHeaders: (final h) => h.userAgent,
        );

        expect(headers.userAgent, isNotNull);
      },
    );
  });

  group('Given a User-Agent header with the strict flag false', () {
    late RelicServer server;

    setUp(() async {
      server = await createServer(strictHeaders: false);
    });

    tearDown(() => server.close());

    group('when an invalid User-Agent header is passed', () {
      test(
        'then it should return null',
        () async {
          final headers = await getServerRequestHeaders(
            server: server,
            touchHeaders: (final _) {},
            headers: {'user-agent': ''},
          );

          expect(Headers.userAgent[headers].valueOrNullIfInvalid, isNull);
          expect(() => headers.userAgent, throwsInvalidHeader);
        },
      );
    });
  });
}
