import 'package:relic/relic.dart';
import 'package:test/test.dart';
import 'package:relic/src/headers/standard_headers_extensions.dart';

import '../headers_test_utils.dart';
import '../docs/strict_validation_docs.dart';

/// Reference: https://developer.mozilla.org/en-US/docs/Web/HTTP/Headers/Sec-Fetch-Dest
/// About empty value test, check the [StrictValidationDocs] class for more details.
void main() {
  group('Given a Sec-Fetch-Dest header with the strict flag true', () {
    late RelicServer server;

    setUp(() async {
      server = await createServer(strictHeaders: true);
    });

    tearDown(() => server.close());

    test(
      'when an empty Sec-Fetch-Dest header is passed then the server should respond with a bad request '
      'including a message that states the value cannot be empty',
      () async {
        expect(
          getServerRequestHeaders(
            server: server,
            touchHeaders: (h) => h.secFetchDest,
            headers: {'sec-fetch-dest': ''},
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
      'when an invalid Sec-Fetch-Dest header is passed then the server should respond with a bad request '
      'including a message that states the value is invalid',
      () async {
        expect(
          getServerRequestHeaders(
            server: server,
            touchHeaders: (h) => h.secFetchDest,
            headers: {'sec-fetch-dest': 'custom-destination'},
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
      'when a Sec-Fetch-Dest header with an invalid value is passed '
      'then the server does not respond with a bad request if the headers '
      'is not actually used',
      () async {
        var headers = await getServerRequestHeaders(
          server: server,
          touchHeaders: (_) {},
          headers: {'sec-fetch-dest': 'custom-destination'},
        );
        expect(headers, isNotNull);
      },
    );

    test(
      'when a valid Sec-Fetch-Dest header is passed then it should parse the destination correctly',
      () async {
        var headers = await getServerRequestHeaders(
          server: server,
          touchHeaders: (h) => h.secFetchDest,
          headers: {'sec-fetch-dest': 'document'},
        );

        expect(headers.secFetchDest?.destination, equals('document'));
      },
    );

    test(
      'when no Sec-Fetch-Dest header is passed then it should return null',
      () async {
        var headers = await getServerRequestHeaders(
          server: server,
          touchHeaders: (h) => h.secFetchDest,
          headers: {},
        );

        expect(headers.secFetchDest, isNull);
      },
    );
  });

  group('Given a Sec-Fetch-Dest header with the strict flag false', () {
    late RelicServer server;

    setUp(() async {
      server = await createServer(strictHeaders: false);
    });

    tearDown(() => server.close());

    group('When an empty Sec-Fetch-Dest header is passed', () {
      test(
        'then it should return null',
        () async {
          var headers = await getServerRequestHeaders(
            server: server,
            touchHeaders: (_) {},
            headers: {},
          );

          expect(headers.secFetchDest, isNull);
        },
      );
    });
  });
}
