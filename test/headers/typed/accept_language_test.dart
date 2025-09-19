import 'package:relic/relic.dart';
import 'package:test/test.dart';

import '../docs/strict_validation_docs.dart';
import '../headers_test_utils.dart';

/// Reference: https://developer.mozilla.org/en-US/docs/Web/HTTP/Headers/Accept-Language
/// For more details on header validation behavior, see the [HeaderValidationDocs] class.
void main() {
  group(
    'Given an Accept-Language header with validation',
    () {
      late RelicServer server;

      setUp(() async {
        server = await createServer();
      });

      tearDown(() => server.close());

      test(
        'when an empty Accept-Language header is passed then the server responds '
        'with a bad request including a message that states the header value '
        'cannot be empty',
        () async {
          expect(
            getServerRequestHeaders(
              server: server,
              touchHeaders: (final h) => h.acceptLanguage,
              headers: {'accept-language': ''},
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
        'when an Accept-Language header with invalid quality values is passed '
        'then the server responds with a bad request including a message that '
        'states the quality value is invalid',
        () async {
          expect(
            getServerRequestHeaders(
              server: server,
              touchHeaders: (final h) => h.acceptLanguage,
              headers: {'accept-language': 'en;q=abc'},
            ),
            throwsA(
              isA<BadRequestException>().having(
                (final e) => e.message,
                'message',
                contains('Invalid quality value'),
              ),
            ),
          );
        },
      );

      test(
        'when an Accept-Language header with wildcard (*) and other languages is '
        'passed then the server responds with a bad request including a message '
        'that states the wildcard (*) cannot be used with other values',
        () async {
          expect(
            getServerRequestHeaders(
              server: server,
              touchHeaders: (final h) => h.acceptLanguage,
              headers: {'accept-language': '*, en'},
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

      test(
        'when an Accept-Language header with empty language is passed then '
        'the server responds with a bad request including a message that '
        'states the language is invalid',
        () async {
          expect(
            getServerRequestHeaders(
              server: server,
              touchHeaders: (final h) => h.acceptLanguage,
              headers: {'accept-language': ';q=0.5'},
            ),
            throwsA(
              isA<BadRequestException>().having(
                (final e) => e.message,
                'message',
                contains('Invalid language'),
              ),
            ),
          );
        },
      );

      test(
        'when an Accept-Language header with an invalid value is passed '
        'then the server does not respond with a bad request if the headers '
        'is not actually used',
        () async {
          final headers = await getServerRequestHeaders(
            server: server,
            touchHeaders: (final _) {},
            headers: {'accept-language': ';q=0.5'},
          );

          expect(headers, isNotNull);
        },
      );

      test(
        'when an Accept-Language header is passed then it should parse the '
        'language correctly',
        () async {
          final headers = await getServerRequestHeaders(
            server: server,
            touchHeaders: (final h) => h.acceptLanguage,
            headers: {'accept-language': 'en'},
          );

          expect(
            headers.acceptLanguage?.languages
                .map((final e) => e.language)
                .toList(),
            equals(['en']),
          );
        },
      );

      test(
        'when an Accept-Language header is passed without quality then the '
        'default quality value should be set',
        () async {
          final headers = await getServerRequestHeaders(
            server: server,
            touchHeaders: (final h) => h.acceptLanguage,
            headers: {'accept-language': 'en'},
          );

          expect(
            headers.acceptLanguage?.languages
                .map((final e) => e.quality)
                .toList(),
            equals([1.0]),
          );
        },
      );

      test(
        'when a mixed case Accept-Language header is passed then it should parse '
        'the language correctly',
        () async {
          final headers = await getServerRequestHeaders(
            server: server,
            touchHeaders: (final h) => h.acceptLanguage,
            headers: {'accept-language': 'En'},
          );

          expect(
            headers.acceptLanguage?.languages
                .map((final e) => e.language)
                .toList(),
            equals(['en']),
          );
        },
      );

      test(
        'when no Accept-Language header is passed then it should return null',
        () async {
          final headers = await getServerRequestHeaders(
            server: server,
            touchHeaders: (final h) => h.acceptLanguage,
            headers: {},
          );

          expect(headers.acceptLanguage, isNull);
        },
      );

      test(
        'when an Accept-Language header with wildcard (*) is passed then it should parse correctly',
        () async {
          final headers = await getServerRequestHeaders(
            server: server,
            touchHeaders: (final h) => h.acceptLanguage,
            headers: {'accept-language': '*'},
          );

          expect(headers.acceptLanguage?.isWildcard, isTrue);
          expect(headers.acceptLanguage?.languages, isEmpty);
        },
      );

      test(
        'when an Accept-Language header with wildcard (*) and quality value is passed '
        'then it should parse the encoding correctly',
        () async {
          final headers = await getServerRequestHeaders(
            server: server,
            touchHeaders: (final h) => h.acceptLanguage,
            headers: {'accept-language': '*;q=0.5'},
          );

          expect(
            headers.acceptLanguage?.languages
                .map((final e) => e.language)
                .toList(),
            equals(['*']),
          );
          expect(
            headers.acceptLanguage?.languages
                .map((final e) => e.quality)
                .toList(),
            equals([0.5]),
          );
        },
      );

      group('when multiple Accept-Language headers are passed', () {
        test(
          'then they should parse the languages correctly',
          () async {
            final headers = await getServerRequestHeaders(
              server: server,
              touchHeaders: (final h) => h.acceptLanguage,
              headers: {'accept-language': 'en, fr, de'},
            );

            expect(
              headers.acceptLanguage?.languages
                  .map((final e) => e.language)
                  .toList(),
              equals(['en', 'fr', 'de']),
            );
          },
        );

        test(
          'then they should parse the qualities correctly',
          () async {
            final headers = await getServerRequestHeaders(
              server: server,
              touchHeaders: (final h) => h.acceptLanguage,
              headers: {'accept-language': 'en, fr, de'},
            );

            expect(
              headers.acceptLanguage?.languages
                  .map((final e) => e.quality)
                  .toList(),
              equals([1.0, 1.0, 1.0]),
            );
          },
        );

        test(
          'with quality values then they should parse the languages correctly',
          () async {
            final headers = await getServerRequestHeaders(
              server: server,
              touchHeaders: (final h) => h.acceptLanguage,
              headers: {'accept-language': 'en;q=1.0, fr;q=0.5, de;q=0.8'},
            );

            expect(
              headers.acceptLanguage?.languages
                  .map((final e) => e.language)
                  .toList(),
              equals(['en', 'fr', 'de']),
            );
          },
        );

        test(
          'with quality values then they should parse the qualities correctly',
          () async {
            final headers = await getServerRequestHeaders(
              server: server,
              touchHeaders: (final h) => h.acceptLanguage,
              headers: {'accept-language': 'en;q=1.0, fr;q=0.5, de;q=0.8'},
            );

            expect(
              headers.acceptLanguage?.languages
                  .map((final e) => e.quality)
                  .toList(),
              equals([1.0, 0.5, 0.8]),
            );
          },
        );

        test(
          'with duplicated values then it should remove duplicates and parse the languages correctly',
          () async {
            final headers = await getServerRequestHeaders(
              server: server,
              touchHeaders: (final h) => h.acceptLanguage,
              headers: {'accept-language': 'en, en, fr, de'},
            );

            expect(
              headers.acceptLanguage?.languages
                  .map((final e) => e.language)
                  .toList(),
              equals(['en', 'fr', 'de']),
            );
          },
        );

        test(
          'with duplicated values then it should remove duplicates and parse the qualities correctly',
          () async {
            final headers = await getServerRequestHeaders(
              server: server,
              touchHeaders: (final h) => h.acceptLanguage,
              headers: {'accept-language': 'en, en, fr, de'},
            );

            expect(
              headers.acceptLanguage?.languages
                  .map((final e) => e.quality)
                  .toList(),
              equals([1.0, 1.0, 1.0]),
            );
          },
        );

        test(
          'with extra whitespace then it should parse the languages correctly',
          () async {
            final headers = await getServerRequestHeaders(
              server: server,
              touchHeaders: (final h) => h.acceptLanguage,
              headers: {'accept-language': ' en , fr , de '},
            );

            expect(
              headers.acceptLanguage?.languages
                  .map((final e) => e.language)
                  .toList(),
              equals(['en', 'fr', 'de']),
            );
          },
        );

        test(
          'with extra whitespace then it should parse the qualities correctly',
          () async {
            final headers = await getServerRequestHeaders(
              server: server,
              touchHeaders: (final h) => h.acceptLanguage,
              headers: {'accept-language': ' en , fr , de '},
            );

            expect(
              headers.acceptLanguage?.languages
                  .map((final e) => e.quality)
                  .toList(),
              equals([1.0, 1.0, 1.0]),
            );
          },
        );
      });
    },
  );

  group(
    'Given an Accept-Language header without validation',
    () {
      late RelicServer server;

      setUp(() async {
        server = await createServer();
      });

      tearDown(() => server.close());

      group('when an invalid Accept-Language header is passed', () {
        test(
          'then it should return null',
          () async {
            final headers = await getServerRequestHeaders(
              server: server,
              touchHeaders: (final _) {},
              headers: {'accept-language': ''},
            );

            expect(
                Headers.acceptLanguage[headers].valueOrNullIfInvalid, isNull);
            expect(() => headers.acceptLanguage, throwsInvalidHeader);
          },
        );
      });

      group(
        'when Accept-Language headers with invalid quality values are passed',
        () {
          test(
            'then it should return null',
            () async {
              final headers = await getServerRequestHeaders(
                server: server,
                touchHeaders: (final _) {},
                headers: {'accept-language': 'en;q=abc, fr, de'},
              );

              expect(
                  Headers.acceptLanguage[headers].valueOrNullIfInvalid, isNull);
              expect(() => headers.acceptLanguage, throwsInvalidHeader);
            },
          );
        },
      );
    },
  );
}
