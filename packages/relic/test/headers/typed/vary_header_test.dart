import 'package:relic/relic.dart';
import 'package:test/test.dart';

import '../docs/strict_validation_docs.dart';
import '../headers_test_utils.dart';

/// Reference: https://developer.mozilla.org/en-US/docs/Web/HTTP/Headers/Vary
/// For more details on header validation behavior, see the [HeaderValidationDocs] class.
void main() {
  group('Given a Vary header with validation', () {
    late RelicServer server;

    setUp(() async {
      server = await createServer();
    });

    tearDown(() => server.close());

    test(
      'when an empty Vary header is passed then the server should respond with a bad request '
      'including a message that states the value cannot be empty',
      () async {
        expect(
          getServerRequestHeaders(
            server: server,
            touchHeaders: (final h) => h.vary,
            headers: {'vary': ''},
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
      'when a Vary header with a wildcard (*) is used with another header then '
      'the server responds with a bad request including a message that states '
      'the wildcard (*) cannot be used with other values',
      () async {
        expect(
          getServerRequestHeaders(
            server: server,
            touchHeaders: (final h) => h.vary,
            headers: {'vary': '* , User-Agent'},
          ),
          throwsA(
            isA<BadRequestException>().having(
              (final e) => e.message,
              'message',
              contains('Wildcard (*) cannot be used with other values'),
            ),
          ),
        );
      },
    );

    test('when a Vary header with an invalid value is passed '
        'then the server does not respond with a bad request if the headers '
        'is not actually used', () async {
      final headers = await getServerRequestHeaders(
        server: server,
        touchHeaders: (_) {},
        headers: {'vary': '* , User-Agent'},
      );

      expect(headers, isNotNull);
    });

    test(
      'when a Vary header is passed then it should parse correctly',
      () async {
        final headers = await getServerRequestHeaders(
          server: server,
          touchHeaders: (final h) => h.vary,
          headers: {'vary': 'Accept-Encoding, User-Agent'},
        );

        expect(headers.vary?.fields, equals(['Accept-Encoding', 'User-Agent']));
      },
    );

    test(
      'when a Vary header with whitespace is passed then it should parse correctly',
      () async {
        final headers = await getServerRequestHeaders(
          server: server,
          touchHeaders: (final h) => h.vary,
          headers: {'vary': ' Accept-Encoding , User-Agent '},
        );

        expect(headers.vary?.fields, equals(['Accept-Encoding', 'User-Agent']));
      },
    );

    test(
      'when a Vary header with wildcard (*) is passed then it should parse correctly',
      () async {
        final headers = await getServerRequestHeaders(
          server: server,
          touchHeaders: (final h) => h.vary,
          headers: {'vary': '*'},
        );

        expect(headers.vary?.isWildcard, isTrue);
        expect(headers.vary?.fields, isEmpty);
      },
    );

    test('when no Vary header is passed then it should return null', () async {
      final headers = await getServerRequestHeaders(
        server: server,
        touchHeaders: (final h) => h.vary,
        headers: {},
      );

      expect(headers.vary, isNull);
    });
  });

  group('Given a Vary header without validation', () {
    late RelicServer server;

    setUp(() async {
      server = await createServer();
    });

    tearDown(() => server.close());

    group('when an empty Vary header is passed', () {
      test('then it should return null', () async {
        final headers = await getServerRequestHeaders(
          server: server,
          touchHeaders: (_) {},
          headers: {'vary': ''},
        );

        expect(Headers.vary[headers].valueOrNullIfInvalid, isNull);
        expect(() => headers.vary, throwsInvalidHeader);
      });
    });
  });
}
