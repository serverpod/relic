import 'package:relic/relic.dart';
import 'package:test/test.dart';
import 'package:relic/src/headers/standard_headers_extensions.dart';

import '../headers_test_utils.dart';
import '../docs/strict_validation_docs.dart';

/// Reference: https://developer.mozilla.org/en-US/docs/Web/HTTP/Headers/Clear-Site-Data
/// About empty value test, check the [StrictValidationDocs] class for more details.
void main() {
  group('Given a Clear-Site-Data header with the strict flag true',
      skip: 'drop strict mode', () {
    late RelicServer server;

    setUp(() async {
      server = await createServer(strictHeaders: true);
    });

    tearDown(() => server.close());

    test(
      'when an empty Clear-Site-Data header is passed then the server should '
      'respond with a bad request including a message that states the value '
      'cannot be empty',
      () async {
        expect(
          () async => await getServerRequestHeaders(
            server: server,
            headers: {'clear-site-data': ''},
          ),
          throwsA(isA<BadRequestException>().having(
            (e) => e.message,
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
          () async => await getServerRequestHeaders(
            server: server,
            headers: {'clear-site-data': 'invalidValue'},
          ),
          throwsA(isA<BadRequestException>().having(
            (e) => e.message,
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
          () async => await getServerRequestHeaders(
            server: server,
            headers: {'clear-site-data': '"cache", "*", "cookies"'},
          ),
          throwsA(isA<BadRequestException>().having(
            (e) => e.message,
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
        var headers = await getServerRequestHeaders(
          server: server,
          headers: {'clear-site-data': '"cache", "*", "cookies"'},
          eagerParseHeaders: false,
        );
        expect(headers, isNotNull);
      },
    );

    test(
      'when a valid Clear-Site-Data header is passed then it should parse the data types correctly',
      () async {
        var headers = await getServerRequestHeaders(
          server: server,
          headers: {'clear-site-data': '"cache", "cookies", "storage"'},
        );

        final dataTypes = headers.clearSiteData?.dataTypes;
        expect(dataTypes?.length, equals(3));
        expect(
          dataTypes?.map((dt) => dt.value).toList(),
          containsAll(['cache', 'cookies', 'storage']),
        );
      },
    );

    test(
      'when a Clear-Site-Data header with wildcard is passed then it should parse correctly',
      () async {
        var headers = await getServerRequestHeaders(
          server: server,
          headers: {'clear-site-data': '*'},
        );

        expect(headers.clearSiteData?.isWildcard, isTrue);
      },
    );

    test(
      'when no Clear-Site-Data header is passed then it should return null',
      () async {
        var headers = await getServerRequestHeaders(
          server: server,
          headers: {},
        );

        expect(headers.clearSiteData_.valueOrNullIfInvalid, isNull);
        expect(() => headers.clearSiteData,
            throwsA(isA<InvalidHeaderException>()));
      },
    );
  });

  group('Given a Clear-Site-Data header with the strict flag false', () {
    late RelicServer server;

    setUp(() async {
      server = await createServer(strictHeaders: false);
    });

    tearDown(() => server.close());

    group('When an empty Clear-Site-Data header is passed', () {
      test(
        'then it should return null',
        () async {
          var headers = await getServerRequestHeaders(
            server: server,
            headers: {'clear-site-data': ''},
          );

          expect(headers.clearSiteData_.valueOrNullIfInvalid, isNull);
          expect(() => headers.clearSiteData,
              throwsA(isA<InvalidHeaderException>()));
        },
      );
    });
  });
}
