import 'package:relic/relic.dart';
import 'package:test/test.dart';
import 'package:relic/src/headers/standard_headers_extensions.dart';

import '../headers_test_utils.dart';
import '../docs/strict_validation_docs.dart';

/// Reference: https://developer.mozilla.org/en-US/docs/Web/HTTP/Headers/Sec-Fetch-Mode
/// About empty value test, check the [StrictValidationDocs] class for more details.
void main() {
  group('Given a Sec-Fetch-Mode header with the strict flag true', () {
    late RelicServer server;

    setUp(() async {
      server = await createServer(strictHeaders: true);
    });

    tearDown(() => server.close());

    test(
      'when an empty Sec-Fetch-Mode header is passed then the server should respond with a bad request '
      'including a message that states the value cannot be empty',
      () async {
        expect(
          () async => await getServerRequestHeaders(
            server: server,
            touchHeaders: (h) => h.secFetchMode,
            headers: {'sec-fetch-mode': ''},
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
      'when an invalid Sec-Fetch-Mode header is passed then the server should respond with a bad request '
      'including a message that states the value is invalid',
      () async {
        expect(
          () async => await getServerRequestHeaders(
            server: server,
            touchHeaders: (h) => h.secFetchMode,
            headers: {'sec-fetch-mode': 'custom-mode'},
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
      'when a Sec-Fetch-Mode header with an invalid value is passed '
      'then the server does not respond with a bad request if the headers '
      'is not actually used',
      () async {
        var headers = await getServerRequestHeaders(
          server: server,
          touchHeaders: (_) {},
          headers: {'sec-fetch-mode': 'custom-mode'},
        );
        expect(headers, isNotNull);
      },
    );

    test(
      'when a valid Sec-Fetch-Mode header is passed then it should parse the mode correctly',
      () async {
        var headers = await getServerRequestHeaders(
          server: server,
          touchHeaders: (h) => h.secFetchMode,
          headers: {'sec-fetch-mode': 'cors'},
        );

        expect(headers.secFetchMode?.mode, equals('cors'));
      },
    );

    test(
      'when no Sec-Fetch-Mode header is passed then it should return null',
      () async {
        var headers = await getServerRequestHeaders(
          server: server,
          touchHeaders: (h) => h.secFetchMode,
          headers: {},
        );

        expect(headers.secFetchMode, isNull);
      },
    );
  });

  group('Given a Sec-Fetch-Mode header with the strict flag false', () {
    late RelicServer server;

    setUp(() async {
      server = await createServer(strictHeaders: false);
    });

    tearDown(() => server.close());

    group('When an empty Sec-Fetch-Mode header is passed', () {
      test(
        'then it should return null',
        () async {
          var headers = await getServerRequestHeaders(
            server: server,
            touchHeaders: (_) {},
            headers: {},
          );

          expect(headers.secFetchMode, isNull);
        },
      );
    });
  });
}
