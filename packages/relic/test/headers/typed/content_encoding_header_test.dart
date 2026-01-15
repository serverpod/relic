import 'package:relic/relic.dart';
import 'package:test/test.dart';

import '../docs/strict_validation_docs.dart';
import '../headers_test_utils.dart';

/// Reference: https://developer.mozilla.org/en-US/docs/Web/HTTP/Headers/Content-Encoding
/// For more details on header validation behavior, see the [HeaderValidationDocs] class.
void main() {
  group('Given a Content-Encoding header with validation', () {
    late RelicServer server;

    setUp(() async {
      server = await createServer();
    });

    tearDown(() => server.close());

    test(
      'when an empty Content-Encoding header is passed then the server responds '
      'with a bad request including a message that states the header value '
      'cannot be empty',
      () async {
        expect(
          getServerRequestHeaders(
            server: server,
            touchHeaders: (final h) => h.contentEncoding,
            headers: {'content-encoding': ''},
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
      'when an invalid Content-Encoding header is passed then the server responds '
      'with a bad request including a message that states the header value '
      'is invalid',
      () async {
        expect(
          getServerRequestHeaders(
            server: server,
            touchHeaders: (final h) => h.contentEncoding,
            headers: {'content-encoding': 'custom-encoding'},
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

    test('when a Content-Encoding header with an invalid value is passed '
        'then the server does not respond with a bad request if the headers '
        'is not actually used', () async {
      final headers = await getServerRequestHeaders(
        server: server,
        touchHeaders: (_) {},
        headers: {'content-encoding': 'custom-encoding'},
      );

      expect(headers, isNotNull);
    });

    test(
      'when a single valid encoding is passed then it should parse correctly',
      () async {
        final headers = await getServerRequestHeaders(
          server: server,
          touchHeaders: (final h) => h.contentEncoding,
          headers: {'content-encoding': 'gzip'},
        );

        expect(
          headers.contentEncoding?.encodings.map((final e) => e.name).toList(),
          equals(['gzip']),
        );
      },
    );

    test(
      'when no Content-Encoding header is passed then it should return null',
      () async {
        final headers = await getServerRequestHeaders(
          server: server,
          touchHeaders: (final h) => h.contentEncoding,
          headers: {},
        );

        expect(headers.contentEncoding, isNull);
      },
    );

    group('when multiple Content-Encoding encodings are passed', () {
      test('then they should parse correctly', () async {
        final headers = await getServerRequestHeaders(
          server: server,
          touchHeaders: (final h) => h.contentEncoding,
          headers: {'content-encoding': 'gzip, deflate'},
        );

        expect(
          headers.contentEncoding?.encodings.map((final e) => e.name).toList(),
          equals(['gzip', 'deflate']),
        );
      });

      test('with extra whitespace should parse correctly', () async {
        final headers = await getServerRequestHeaders(
          server: server,
          touchHeaders: (final h) => h.contentEncoding,
          headers: {'content-encoding': ' gzip , deflate '},
        );

        expect(
          headers.contentEncoding?.encodings.map((final e) => e.name).toList(),
          equals(['gzip', 'deflate']),
        );
      });

      test(
        'with duplicate encodings should parse correctly and remove duplicates',
        () async {
          final headers = await getServerRequestHeaders(
            server: server,
            touchHeaders: (final h) => h.contentEncoding,
            headers: {'content-encoding': 'gzip, deflate, gzip'},
          );

          expect(
            headers.contentEncoding?.encodings
                .map((final e) => e.name)
                .toList(),
            equals(['gzip', 'deflate']),
          );
        },
      );
    });
  });

  group('Given a Content-Encoding header without validation', () {
    late RelicServer server;

    setUp(() async {
      server = await createServer();
    });

    tearDown(() => server.close());

    group('when an invalid Content-Encoding header is passed', () {
      test('then it should return null', () async {
        final headers = await getServerRequestHeaders(
          server: server,
          touchHeaders: (_) {},
          headers: {'content-encoding': ''},
        );

        expect(Headers.contentEncoding[headers].valueOrNullIfInvalid, isNull);
        expect(() => headers.contentEncoding, throwsInvalidHeader);
      });
    });
  });
}
