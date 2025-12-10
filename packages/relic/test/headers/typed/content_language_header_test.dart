import 'package:relic/relic.dart';
import 'package:test/test.dart';

import '../docs/strict_validation_docs.dart';
import '../headers_test_utils.dart';

/// Reference: https://developer.mozilla.org/en-US/docs/Web/HTTP/Headers/Content-Language
/// For more details on header validation behavior, see the [HeaderValidationDocs] class.
void main() {
  group('Given a Content-Language header with validation', () {
    late RelicServer server;

    setUp(() async {
      server = await createServer();
    });

    tearDown(() => server.close());

    test(
      'when an empty Content-Language header is passed then the server responds '
      'with a bad request including a message that states the header value '
      'cannot be empty',
      () async {
        expect(
          getServerRequestHeaders(
            server: server,
            touchHeaders: (final h) => h.contentLanguage,
            headers: {'content-language': ''},
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
      'when an invalid language code is passed then the server responds with a '
      'bad request including a message that states the language code is invalid',
      () async {
        expect(
          getServerRequestHeaders(
            server: server,
            touchHeaders: (final h) => h.contentLanguage,
            headers: {'content-language': 'en-123'},
          ),
          throwsA(
            isA<BadRequestException>().having(
              (final e) => e.message,
              'message',
              contains('Invalid language code'),
            ),
          ),
        );
      },
    );

    test('when a Content-Language header with an invalid value is passed '
        'then the server does not respond with a bad request if the headers '
        'is not actually used', () async {
      final headers = await getServerRequestHeaders(
        server: server,
        touchHeaders: (_) {},
        headers: {'content-language': 'en-123'},
      );

      expect(headers, isNotNull);
    });

    test(
      'when a single valid language is passed then it should parse correctly',
      () async {
        final headers = await getServerRequestHeaders(
          server: server,
          touchHeaders: (final h) => h.contentLanguage,
          headers: {'content-language': 'en'},
        );

        expect(headers.contentLanguage?.languages, equals(['en']));
      },
    );

    group('when multiple Content-Language languages are passed', () {
      test('then they should parse correctly', () async {
        final headers = await getServerRequestHeaders(
          server: server,
          touchHeaders: (final h) => h.contentLanguage,
          headers: {'content-language': 'en, fr, de'},
        );

        expect(headers.contentLanguage?.languages, equals(['en', 'fr', 'de']));
      });

      test('with extra whitespace then they should parse correctly', () async {
        final headers = await getServerRequestHeaders(
          server: server,
          touchHeaders: (final h) => h.contentLanguage,
          headers: {'content-language': ' en , fr , de '},
        );

        expect(headers.contentLanguage?.languages, equals(['en', 'fr', 'de']));
      });

      test(
        'with duplicate languages then they should parse correctly and remove duplicates',
        () async {
          final headers = await getServerRequestHeaders(
            server: server,
            touchHeaders: (final h) => h.contentLanguage,
            headers: {'content-language': 'en, fr, de, en'},
          );

          expect(
            headers.contentLanguage?.languages,
            equals(['en', 'fr', 'de']),
          );
        },
      );
    });

    test(
      'when no Content-Language header is passed then it should return null',
      () async {
        final headers = await getServerRequestHeaders(
          server: server,
          touchHeaders: (final h) => h.contentLanguage,
          headers: {},
        );

        expect(headers.contentLanguage, isNull);
      },
    );
  });

  group('Given a Content-Language header without validation', () {
    late RelicServer server;

    setUp(() async {
      server = await createServer();
    });

    tearDown(() => server.close());

    group('when an invalid Content-Language header is passed', () {
      test('then it should return null', () async {
        final headers = await getServerRequestHeaders(
          server: server,
          touchHeaders: (_) {},
          headers: {'content-language': 'en-123'},
        );

        expect(Headers.contentLanguage[headers].valueOrNullIfInvalid, isNull);
        expect(() => headers.contentLanguage, throwsInvalidHeader);
      });
    });
  });
}
