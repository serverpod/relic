import 'package:relic/relic.dart';
import 'package:test/test.dart';

import '../docs/strict_validation_docs.dart';
import '../headers_test_utils.dart';

/// Reference: https://developer.mozilla.org/en-US/docs/Web/HTTP/Headers/Transfer-Encoding
/// For more details on header validation behavior, see the [HeaderValidationDocs] class.
void main() {
  group('Given a Transfer-Encoding header with validation', () {
    late RelicServer server;

    setUp(() async {
      server = await createServer();
    });

    tearDown(() => server.close());

    test(
      'when an empty Transfer-Encoding header is passed then the server should respond with a bad request '
      'including a message that states the encodings cannot be empty',
      () async {
        expect(
          getServerRequestHeaders(
            server: server,
            touchHeaders: (final h) => h.transferEncoding,
            headers: {'transfer-encoding': ''},
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
      'when an invalid Transfer-Encoding header is passed then the server should respond with a bad request '
      'including a message that states the value is invalid',
      () async {
        expect(
          getServerRequestHeaders(
            server: server,
            touchHeaders: (final h) => h.transferEncoding,
            headers: {'transfer-encoding': 'custom-encoding'},
          ),
          throwsA(
            isA<BadRequestException>().having(
              (final e) => e.message,
              'message',
              contains('Invalid value'),
            ),
          ),
        );
      },
    );

    test('when a Transfer-Encoding header with an invalid value is passed '
        'then the server does not respond with a bad request if the headers '
        'is not actually used', () async {
      final headers = await getServerRequestHeaders(
        server: server,
        touchHeaders: (_) {},
        headers: {'transfer-encoding': 'custom-encoding'},
      );

      expect(headers, isNotNull);
    });

    test(
      'when a valid Transfer-Encoding header is passed then it should parse the encodings correctly',
      () async {
        final headers = await getServerRequestHeaders(
          server: server,
          touchHeaders: (final h) => h.transferEncoding,
          headers: {'transfer-encoding': 'gzip, chunked'},
        );

        expect(
          headers.transferEncoding?.encodings.map((final e) => e.name),
          equals(['gzip', 'chunked']),
        );
      },
    );

    /// According to the HTTP/1.1 specification (RFC 9112), the 'chunked' transfer
    /// encoding must be the final encoding applied to the response body.
    test(
      'when a valid Transfer-Encoding header is passed with "chunked" as not the last '
      'encoding then it should parse the encodings correctly and reorder them sot the '
      'chunked encoding is the last encoding',
      () async {
        final headers = await getServerRequestHeaders(
          server: server,
          touchHeaders: (final h) => h.transferEncoding,
          headers: {'transfer-encoding': 'chunked, gzip'},
        );

        expect(
          headers.transferEncoding?.encodings.map((final e) => e.name),
          equals(['gzip', 'chunked']),
        );
      },
    );

    test(
      'when a Transfer-Encoding header with duplicate encodings is passed then '
      'it should parse the encodings correctly and remove duplicates',
      () async {
        final headers = await getServerRequestHeaders(
          server: server,
          touchHeaders: (final h) => h.transferEncoding,
          headers: {'transfer-encoding': 'gzip, chunked, chunked'},
        );

        expect(
          headers.transferEncoding?.encodings.map((final e) => e.name),
          equals(['gzip', 'chunked']),
        );
      },
    );

    test(
      'when a Transfer-Encoding header contains "chunked" then isChunked should be true',
      () async {
        final headers = await getServerRequestHeaders(
          server: server,
          touchHeaders: (final h) => h.transferEncoding,
          headers: {'transfer-encoding': 'gzip, chunked'},
        );

        expect(
          headers.transferEncoding?.encodings.any(
            (final e) => e.name == TransferEncoding.chunked.name,
          ),
          isTrue,
        );
      },
    );

    test(
      'when no Transfer-Encoding header is passed then it should return null',
      () async {
        final headers = await getServerRequestHeaders(
          server: server,
          touchHeaders: (final h) => h.transferEncoding,
          headers: {},
        );

        expect(headers.transferEncoding, isNull);
      },
    );
  });

  group('Given a Transfer-Encoding header without validation', () {
    late RelicServer server;

    setUp(() async {
      server = await createServer();
    });

    tearDown(() => server.close());

    group('when an empty Transfer-Encoding header is passed', () {
      test('then it should return null', () async {
        final headers = await getServerRequestHeaders(
          server: server,
          touchHeaders: (_) {},
          headers: {'transfer-encoding': ''},
        );

        expect(Headers.transferEncoding[headers].valueOrNullIfInvalid, isNull);
        expect(() => headers.transferEncoding, throwsInvalidHeader);
      });
    });
  });
}
