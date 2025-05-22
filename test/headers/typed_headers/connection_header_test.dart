import 'package:relic/relic.dart';
import 'package:test/test.dart';

import '../docs/strict_validation_docs.dart';
import '../headers_test_utils.dart';

/// Reference: https://developer.mozilla.org/en-US/docs/Web/HTTP/Headers/Connection
/// About empty value test, check the [StrictValidationDocs] class for more details.
void main() {
  group('Given a Connection header with the strict flag true', () {
    late RelicServer server;

    setUp(() async {
      server = await createServer(strictHeaders: true);
    });

    tearDown(() => server.close());

    test(
      'when an empty Connection header is passed then the server responds '
      'with a bad request including a message that states the directives '
      'cannot be empty',
      () async {
        expect(
          getServerRequestHeaders(
            server: server,
            touchHeaders: (final h) => h.connection,
            headers: {'connection': ''},
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
      'when an invalid Connection header is passed then the server responds '
      'with a bad request including a message that states the value '
      'is invalid',
      () async {
        expect(
          getServerRequestHeaders(
            server: server,
            touchHeaders: (final h) => h.connection,
            headers: {'connection': 'custom-directive'},
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
      'when a Connection header with an invalid value is passed '
      'then the server does not respond with a bad request if the headers '
      'is not actually used',
      () async {
        final headers = await getServerRequestHeaders(
          server: server,
          touchHeaders: (final _) {},
          headers: {'connection': 'invalid-connection-format'},
        );

        expect(headers, isNotNull);
      },
    );

    test(
      'when a Connection header with directives are passed then they should be parsed correctly',
      () async {
        final headers = await getServerRequestHeaders(
          server: server,
          touchHeaders: (final h) => h.connection,
          headers: {'connection': 'keep-alive, upgrade'},
        );

        expect(
          headers.connection?.directives.map((final d) => d.value),
          containsAll(['keep-alive', 'upgrade']),
        );
      },
    );

    test(
      'when a Connection header with duplicate directives are passed then '
      'they should be parsed correctly and remove duplicates',
      () async {
        final headers = await getServerRequestHeaders(
          server: server,
          touchHeaders: (final h) => h.connection,
          headers: {'connection': 'keep-alive, upgrade, keep-alive'},
        );

        expect(
          headers.connection?.directives.map((final d) => d.value),
          containsAll(['keep-alive', 'upgrade']),
        );
      },
    );

    test(
      'when a Connection header with keep-alive is passed then isKeepAlive should be true',
      () async {
        final headers = await getServerRequestHeaders(
          server: server,
          touchHeaders: (final h) => h.connection,
          headers: {'connection': 'keep-alive'},
        );

        expect(headers.connection?.isKeepAlive, isTrue);
      },
    );

    test(
      'when a Connection header with close is passed then isClose should be true',
      () async {
        final headers = await getServerRequestHeaders(
          server: server,
          touchHeaders: (final h) => h.connection,
          headers: {'connection': 'close'},
        );

        expect(headers.connection?.isClose, isTrue);
      },
    );
  });

  group('Given a Connection header with the strict flag false', () {
    late RelicServer server;

    setUp(() async {
      server = await createServer(strictHeaders: false);
    });

    tearDown(() => server.close());

    group(
      'when an invalid Connection header is passed',
      () {
        test(
          'then it should return null',
          () async {
            final headers = await getServerRequestHeaders(
              server: server,
              touchHeaders: (final _) {},
              headers: {'connection': ''},
            );

            expect(Headers.connection[headers].valueOrNullIfInvalid, isNull);
            expect(() => headers.connection, throwsInvalidHeader);
          },
        );
      },
    );
  });
}
