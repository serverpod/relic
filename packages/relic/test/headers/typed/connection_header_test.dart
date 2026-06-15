import 'package:relic/relic.dart';
import 'package:test/test.dart';

import '../docs/strict_validation_docs.dart';
import '../headers_test_utils.dart';

/// Reference: https://developer.mozilla.org/en-US/docs/Web/HTTP/Headers/Connection
/// For more details on header validation behavior, see the [HeaderValidationDocs] class.
void main() {
  group('Given a Connection header with validation', () {
    late RelicServer server;

    setUp(() async {
      server = await createServer();
    });

    tearDown(() => server.close());

    // Note: rejection of an empty Connection value is covered by a direct unit
    // test in packages/relic_core/test/headers/typed/connection_header_test.dart.
    // It cannot run as a server round-trip: dart:io's HttpServer drops an empty
    // Connection request header (a hop-by-hop, connection-managed field), so it
    // never reaches the handler.

    test('when a non-token Connection value is passed then the server responds '
        'with a bad request', () async {
      expect(
        getServerRequestHeaders(
          server: server,
          touchHeaders: (final h) => h.connection,
          headers: {'connection': 'bad directive'},
        ),
        throwsA(isA<BadRequestException>()),
      );
    });

    test('when an unknown but valid connection-option is passed '
        'then it parses (open token set)', () async {
      final headers = await getServerRequestHeaders(
        server: server,
        touchHeaders: (final h) => h.connection,
        headers: {'connection': 'TE'},
      );

      expect(
        headers.connection?.directives.map((final d) => d.value),
        equals(['te']),
      );
    });

    test('when a non-token Connection value is passed '
        'then the server does not respond with a bad request if the headers '
        'is not actually used', () async {
      final headers = await getServerRequestHeaders(
        server: server,
        touchHeaders: (_) {},
        headers: {'connection': 'bad directive'},
      );

      expect(headers, isNotNull);
    });

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

    test('when a Connection header with duplicate directives are passed then '
        'they should be parsed correctly and remove duplicates', () async {
      final headers = await getServerRequestHeaders(
        server: server,
        touchHeaders: (final h) => h.connection,
        headers: {'connection': 'keep-alive, upgrade, keep-alive'},
      );

      expect(
        headers.connection?.directives.map((final d) => d.value),
        containsAll(['keep-alive', 'upgrade']),
      );
    });

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

  group('Given a Connection header without validation', () {
    late RelicServer server;

    setUp(() async {
      server = await createServer();
    });

    tearDown(() => server.close());

    group('when an invalid Connection header is passed', () {
      test('then it should return null', () async {
        final headers = await getServerRequestHeaders(
          server: server,
          touchHeaders: (_) {},
          headers: {'connection': 'bad directive'},
        );

        expect(Headers.connection[headers].valueOrNullIfInvalid, isNull);
        expect(() => headers.connection, throwsInvalidHeader);
      });
    });
  });
}
