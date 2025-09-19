import 'package:relic/relic.dart';
import 'package:test/test.dart';

import '../docs/strict_validation_docs.dart';
import '../headers_test_utils.dart';

/// Reference: https://developer.mozilla.org/en-US/docs/Web/HTTP/Headers/Clear-Site-Data
/// For more details on header validation behavior, see the [HeaderValidationDocs] class.
void main() {
  group('Given a Clear-Site-Data header with validation', () {
    late RelicServer server;

    setUp(() async {
      server = await createServer();
    });

    tearDown(() => server.close());

    test(
      'when an empty Clear-Site-Data header is passed then the server should '
      'respond with a bad request including a message that states the value '
      'cannot be empty',
      () async {
        expect(
          getServerRequestHeaders(
            server: server,
            touchHeaders: (final h) => h.clearSiteData,
            headers: {'clear-site-data': ''},
          ),
          throwsA(isA<BadRequestException>().having(
            (final e) => e.message,
            'message',
            contains('Value cannot be empty'),
          )),
        );
      },
    );

    test(
      'when an invalid Clear-Site-Data header is passed then the server should '
      'respond with a bad request including a message that states the value '
      'is invalid',
      () async {
        expect(
          getServerRequestHeaders(
            server: server,
            touchHeaders: (final h) => h.clearSiteData,
            headers: {'clear-site-data': 'invalidValue'},
          ),
          throwsA(isA<BadRequestException>().having(
            (final e) => e.message,
            'message',
            contains('Invalid value'),
          )),
        );
      },
    );

    test(
      'when a Clear-Site-Data header with wildcard (*) and other data types is '
      'passed then the server should respond with a bad request including a '
      'message that states the wildcard cannot be used with other values',
      () async {
        expect(
          getServerRequestHeaders(
            server: server,
            touchHeaders: (final h) => h.clearSiteData,
            headers: {'clear-site-data': '"cache", "*", "cookies"'},
          ),
          throwsA(isA<BadRequestException>().having(
            (final e) => e.message,
            'message',
            contains('Wildcard (*) cannot be used with other values'),
          )),
        );
      },
    );

    test(
      'when a Clear-Site-Data header with an invalid value is passed '
      'then the server does not respond with a bad request if the headers '
      'is not actually used',
      () async {
        final headers = await getServerRequestHeaders(
          server: server,
          touchHeaders: (final _) {},
          headers: {'clear-site-data': '"cache", "*", "cookies"'},
        );
        expect(headers, isNotNull);
      },
    );

    test(
      'when a valid Clear-Site-Data header is passed then it should parse the data types correctly',
      () async {
        final headers = await getServerRequestHeaders(
          server: server,
          touchHeaders: (final h) => h.clearSiteData,
          headers: {'clear-site-data': '"cache", "cookies", "storage"'},
        );

        final dataTypes = headers.clearSiteData?.dataTypes;
        expect(dataTypes?.length, equals(3));
        expect(
          dataTypes?.map((final dt) => dt.value).toList(),
          containsAll(['cache', 'cookies', 'storage']),
        );
      },
    );

    test(
      'when a Clear-Site-Data header with wildcard is passed then it should parse correctly',
      () async {
        final headers = await getServerRequestHeaders(
          server: server,
          touchHeaders: (final h) => h.clearSiteData,
          headers: {'clear-site-data': '*'},
        );

        expect(headers.clearSiteData?.isWildcard, isTrue);
      },
    );

    test(
      'when no Clear-Site-Data header is passed then it should return null',
      () async {
        final headers = await getServerRequestHeaders(
          server: server,
          touchHeaders: (final h) => h.clearSiteData,
          headers: {},
        );

        expect(headers.clearSiteData, isNull);
      },
    );
  });

  group('Given a Clear-Site-Data header without validation', () {
    late RelicServer server;

    setUp(() async {
      server = await createServer();
    });

    tearDown(() => server.close());

    group('When an empty Clear-Site-Data header is passed', () {
      test(
        'then it should return null',
        () async {
          final headers = await getServerRequestHeaders(
            server: server,
            touchHeaders: (final _) {},
            headers: {'clear-site-data': ''},
          );

          expect(Headers.clearSiteData[headers].valueOrNullIfInvalid, isNull);
          expect(() => headers.clearSiteData, throwsInvalidHeader);
        },
      );
    });
  });
}
