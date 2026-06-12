import 'package:relic/relic.dart';
import 'package:test/test.dart';

import '../docs/strict_validation_docs.dart';
import '../headers_test_utils.dart';

/// Reference: https://developer.mozilla.org/en-US/docs/Web/HTTP/Headers/From
/// For more details on header validation behavior, see the [HeaderValidationDocs] class.
void main() {
  group('Given a From header with validation', () {
    late RelicServer server;

    setUp(() async {
      server = await createServer();
    });

    tearDown(() => server.close());

    test(
      'when an empty From header is passed '
      'then the server responds with a bad request stating the value cannot be empty',
      () async {
        expect(
          getServerRequestHeaders(
            server: server,
            touchHeaders: (final h) => h.from,
            headers: {'from': ''},
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

    test('when a From header carries a plain addr-spec '
        'then it is parsed as the mailbox', () async {
      final headers = await getServerRequestHeaders(
        server: server,
        touchHeaders: (final h) => h.from,
        headers: {'from': 'user@example.com'},
      );

      expect(headers.from?.mailbox, equals('user@example.com'));
    });

    test('when a From header carries a name-addr form '
        'then it is preserved verbatim', () async {
      final headers = await getServerRequestHeaders(
        server: server,
        touchHeaders: (final h) => h.from,
        headers: {'from': 'Webmaster <webmaster@example.org>'},
      );

      expect(
        headers.from?.mailbox,
        equals('Webmaster <webmaster@example.org>'),
      );
    });

    test(
      'when a From header carries a value that is not a strict email '
      'then it is accepted as-is (advisory mailbox, not format-validated)',
      () async {
        final headers = await getServerRequestHeaders(
          server: server,
          touchHeaders: (final h) => h.from,
          headers: {'from': 'invalid-email-format'},
        );

        expect(headers.from?.mailbox, equals('invalid-email-format'));
      },
    );

    test('when a From header has surrounding whitespace '
        'then the mailbox is trimmed', () async {
      final headers = await getServerRequestHeaders(
        server: server,
        touchHeaders: (final h) => h.from,
        headers: {'from': ' user@example.com '},
      );

      expect(headers.from?.mailbox, equals('user@example.com'));
    });

    test(
      'when an empty From header is passed '
      'then the server does not respond with a bad request if the headers is not actually used',
      () async {
        final headers = await getServerRequestHeaders(
          server: server,
          touchHeaders: (_) {},
          headers: {'from': ''},
        );

        expect(headers, isNotNull);
      },
    );

    test('when no From header is passed then it should return null', () async {
      final headers = await getServerRequestHeaders(
        server: server,
        touchHeaders: (final h) => h.from,
        headers: {},
      );

      expect(headers.from, isNull);
    });
  });

  group('Given a From header without validation', () {
    late RelicServer server;

    setUp(() async {
      server = await createServer();
    });

    tearDown(() => server.close());

    group('when an empty From header is passed', () {
      test('then it should return null', () async {
        final headers = await getServerRequestHeaders(
          server: server,
          touchHeaders: (_) {},
          headers: {'from': ''},
        );

        expect(Headers.from[headers].valueOrNullIfInvalid, isNull);
        expect(() => headers.from, throwsInvalidHeader);
      });
    });
  });
}
