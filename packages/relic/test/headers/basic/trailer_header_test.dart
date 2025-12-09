import 'package:relic/relic.dart';
import 'package:test/test.dart';

import '../docs/strict_validation_docs.dart';
import '../headers_test_utils.dart';

/// Reference: https://developer.mozilla.org/en-US/docs/Web/HTTP/Headers/Trailer
/// For more details on header validation behavior, see the [HeaderValidationDocs] class.
void main() {
  group('Given a Trailer header with validation', () {
    late RelicServer server;

    setUp(() async {
      server = await createServer();
    });

    tearDown(() => server.close());

    test(
      'when an empty Trailer header is passed then the server should respond with a bad request '
      'including a message that states the value cannot be empty',
      () async {
        expect(
          getServerRequestHeaders(
            server: server,
            headers: {'trailer': ''},
            touchHeaders: (final h) => h.trailer,
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

    test('when a Trailer header with an empty value is passed '
        'then the server does not respond with a bad request if the headers '
        'is not actually used', () async {
      final headers = await getServerRequestHeaders(
        server: server,
        touchHeaders: (_) {},
        headers: {'trailer': ''},
      );

      expect(headers, isNotNull);
    });

    test(
      'when a valid Trailer header is passed then it should parse correctly',
      () async {
        final headers = await getServerRequestHeaders(
          server: server,
          headers: {'trailer': 'Expires, Content-MD5, Content-Language'},
          touchHeaders: (final h) => h.trailer,
        );

        expect(
          headers.trailer,
          equals(['Expires', 'Content-MD5', 'Content-Language']),
        );
      },
    );

    test(
      'when a Trailer header with whitespace is passed then it should parse correctly',
      () async {
        final headers = await getServerRequestHeaders(
          server: server,
          headers: {'trailer': ' Expires , Content-MD5 , Content-Language '},
          touchHeaders: (final h) => h.trailer,
        );

        expect(
          headers.trailer,
          equals(['Expires', 'Content-MD5', 'Content-Language']),
        );
      },
    );

    test(
      'when a Trailer header with custom values is passed then it should parse correctly',
      () async {
        final headers = await getServerRequestHeaders(
          server: server,
          headers: {'trailer': 'custom-header, AnotherHeader'},
          touchHeaders: (final h) => h.trailer,
        );

        expect(headers.trailer, equals(['custom-header', 'AnotherHeader']));
      },
    );

    test(
      'when no Trailer header is passed then it should return null',
      () async {
        final headers = await getServerRequestHeaders(
          server: server,
          headers: {},
          touchHeaders: (final h) => h.lastModified,
        );

        expect(headers.trailer, isNull);
      },
    );
  });

  group('Given a Trailer header without validation', () {
    late RelicServer server;

    setUp(() async {
      server = await createServer();
    });

    tearDown(() => server.close());

    test(
      'when a custom Trailer header is passed then it should parse correctly',
      () async {
        final headers = await getServerRequestHeaders(
          server: server,
          touchHeaders: (_) {},
          headers: {'trailer': 'custom-header'},
        );

        expect(headers.trailer, equals(['custom-header']));
      },
    );
  });
}
