import 'package:relic/relic.dart';
import 'package:test/test.dart';
import 'package:relic/src/headers/standard_headers_extensions.dart';

import '../headers_test_utils.dart';
import '../docs/strict_validation_docs.dart';

/// Reference: https://developer.mozilla.org/en-US/docs/Web/HTTP/Headers/Content-Language
/// About empty value test, check the [StrictValidationDocs] class for more details.
void main() {
  group('Given a Content-Language header with the strict flag true', () {
    late RelicServer server;

    setUp(() async {
      server = await createServer(strictHeaders: true);
    });

    tearDown(() => server.close());

    test(
      'when an empty Content-Language header is passed then the server responds '
      'with a bad request including a message that states the header value '
      'cannot be empty',
      () async {
        expect(
          () async => await getServerRequestHeaders(
            server: server,
            touchHeaders: (h) => h.contentLanguage,
            headers: {'content-language': ''},
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
      'when an invalid language code is passed then the server responds with a '
      'bad request including a message that states the language code is invalid',
      () async {
        expect(
          () async => await getServerRequestHeaders(
            server: server,
            touchHeaders: (h) => h.contentLanguage,
            headers: {'content-language': 'en-123'},
          ),
          throwsA(
            isA<BadRequestException>().having(
              (e) => e.message,
              'message',
              contains('Invalid language code'),
            ),
          ),
        );
      },
    );

    test(
      'when a Content-Language header with an invalid value is passed '
      'then the server does not respond with a bad request if the headers '
      'is not actually used',
      () async {
        var headers = await getServerRequestHeaders(
          server: server,
          touchHeaders: (_) {},
          headers: {'content-language': 'en-123'},
        );

        expect(headers, isNotNull);
      },
    );

    test(
      'when a single valid language is passed then it should parse correctly',
      () async {
        var headers = await getServerRequestHeaders(
          server: server,
          touchHeaders: (h) => h.contentLanguage,
          headers: {'content-language': 'en'},
        );

        expect(headers.contentLanguage?.languages, equals(['en']));
      },
    );

    group('when multiple Content-Language languages are passed', () {
      test('then they should parse correctly', () async {
        var headers = await getServerRequestHeaders(
          server: server,
          touchHeaders: (h) => h.contentLanguage,
          headers: {'content-language': 'en, fr, de'},
        );

        expect(headers.contentLanguage?.languages, equals(['en', 'fr', 'de']));
      });

      test('with extra whitespace then they should parse correctly', () async {
        var headers = await getServerRequestHeaders(
          server: server,
          touchHeaders: (h) => h.contentLanguage,
          headers: {'content-language': ' en , fr , de '},
        );

        expect(headers.contentLanguage?.languages, equals(['en', 'fr', 'de']));
      });

      test(
          'with duplicate languages then they should parse correctly and remove duplicates',
          () async {
        var headers = await getServerRequestHeaders(
          server: server,
          touchHeaders: (h) => h.contentLanguage,
          headers: {'content-language': 'en, fr, de, en'},
        );

        expect(headers.contentLanguage?.languages, equals(['en', 'fr', 'de']));
      });
    });

    test(
      'when no Content-Language header is passed then it should return null',
      () async {
        var headers = await getServerRequestHeaders(
          server: server,
          touchHeaders: (h) => h.contentLanguage,
          headers: {},
        );

        expect(headers.contentLanguage, isNull);
      },
    );
  });

  group('Given a Content-Language header with the strict flag false', () {
    late RelicServer server;

    setUp(() async {
      server = await createServer(strictHeaders: false);
    });

    tearDown(() => server.close());

    group('when an invalid Content-Language header is passed', () {
      test(
        'then it should return null',
        () async {
          var headers = await getServerRequestHeaders(
            server: server,
            touchHeaders: (_) {},
            headers: {'content-language': 'en-123'},
          );

          expect(headers.contentLanguage_.valueOrNullIfInvalid, isNull);
          expect(() => headers.contentLanguage,
              throwsA(isA<InvalidHeaderException>()));
        },
      );
    });
  });
}
