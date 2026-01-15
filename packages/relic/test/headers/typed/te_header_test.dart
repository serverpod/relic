import 'package:relic/relic.dart';
import 'package:test/test.dart';

import '../docs/strict_validation_docs.dart';
import '../headers_test_utils.dart';

/// Reference: https://developer.mozilla.org/en-US/docs/Web/HTTP/Headers/TE
/// For more details on header validation behavior, see the [HeaderValidationDocs] class.
void main() {
  group('Given a TE header with validation', () {
    late RelicServer server;

    setUp(() async {
      server = await createServer();
    });

    tearDown(() => server.close());

    test('when an empty TE header is passed then the server responds '
        'with a bad request including a message that states the header value '
        'cannot be empty', () async {
      expect(
        getServerRequestHeaders(
          server: server,
          touchHeaders: (final h) => h.te,
          headers: {'te': ''},
        ),
        throwsA(
          isA<BadRequestException>().having(
            (final e) => e.message,
            'message',
            contains('Value cannot be empty'),
          ),
        ),
      );
    });

    test('when a TE header with invalid quality values is passed '
        'then the server responds with a bad request including a message that '
        'states the quality value is invalid', () async {
      expect(
        getServerRequestHeaders(
          server: server,
          touchHeaders: (final h) => h.te,
          headers: {'te': 'trailers;q=abc'},
        ),
        throwsA(
          isA<BadRequestException>().having(
            (final e) => e.message,
            'message',
            contains('Invalid quality value'),
          ),
        ),
      );
    });

    test('when a TE header with invalid encoding is passed '
        'then the server responds with a bad request including a message that '
        'states the encoding is invalid', () async {
      expect(
        getServerRequestHeaders(
          server: server,
          touchHeaders: (final h) => h.te,
          headers: {'te': ';q=1.0'},
        ),
        throwsA(
          isA<BadRequestException>().having(
            (final e) => e.message,
            'message',
            contains('Invalid encoding'),
          ),
        ),
      );
    });

    test('when a TE header with an invalid value is passed '
        'then the server does not respond with a bad request if the headers '
        'is not actually used', () async {
      final headers = await getServerRequestHeaders(
        server: server,
        touchHeaders: (_) {},
        headers: {'te': 'trailers;q=abc'},
      );

      expect(headers, isNotNull);
    });

    test('when a TE header is passed then it should parse the '
        'encoding correctly', () async {
      final headers = await getServerRequestHeaders(
        server: server,
        touchHeaders: (final h) => h.te,
        headers: {'te': 'trailers'},
      );

      expect(
        headers.te?.encodings.map((final e) => e.encoding).toList(),
        equals(['trailers']),
      );
    });

    test('when a TE header is passed without quality then the '
        'default quality value should be set', () async {
      final headers = await getServerRequestHeaders(
        server: server,
        touchHeaders: (final h) => h.te,
        headers: {'te': 'trailers'},
      );

      expect(
        headers.te?.encodings.map((final e) => e.quality).toList(),
        equals([1.0]),
      );
    });

    test('when no TE header is passed then it should return null', () async {
      final headers = await getServerRequestHeaders(
        server: server,
        touchHeaders: (final h) => h.te,
        headers: {},
      );

      expect(headers.te, isNull);
    });

    group('when multiple TE headers are passed', () {
      test('then they should parse the encodings correctly', () async {
        final headers = await getServerRequestHeaders(
          server: server,
          touchHeaders: (final h) => h.te,
          headers: {'te': 'trailers, deflate, gzip'},
        );

        expect(
          headers.te?.encodings.map((final e) => e.encoding).toList(),
          equals(['trailers', 'deflate', 'gzip']),
        );
      });

      test(
        'with quantities then they should parse the encodings correctly',
        () async {
          final headers = await getServerRequestHeaders(
            server: server,
            touchHeaders: (final h) => h.te,
            headers: {'te': 'trailers;q=1.0, deflate;q=0.5, gzip;q=0.8'},
          );

          expect(
            headers.te?.encodings.map((final e) => e.encoding).toList(),
            equals(['trailers', 'deflate', 'gzip']),
          );
        },
      );

      test(
        'with quality values then they should parse the qualities correctly',
        () async {
          final headers = await getServerRequestHeaders(
            server: server,
            touchHeaders: (final h) => h.te,
            headers: {'te': 'trailers;q=1.0, deflate;q=0.5, gzip;q=0.8'},
          );

          expect(
            headers.te?.encodings.map((final e) => e.quality).toList(),
            equals([1.0, 0.5, 0.8]),
          );
        },
      );

      test(
        'with extra whitespace then they should parse the encodings correctly',
        () async {
          final headers = await getServerRequestHeaders(
            server: server,
            touchHeaders: (final h) => h.te,
            headers: {'te': ' trailers , deflate , gzip '},
          );

          expect(
            headers.te?.encodings.map((final e) => e.encoding).toList(),
            equals(['trailers', 'deflate', 'gzip']),
          );
        },
      );
    });
  });

  group('Given a TE header without validation', () {
    late RelicServer server;

    setUp(() async {
      server = await createServer();
    });

    tearDown(() => server.close());

    group('when an empty TE header is passed', () {
      test('then it should return null', () async {
        final headers = await getServerRequestHeaders(
          server: server,
          touchHeaders: (_) {},
          headers: {'te': ''},
        );

        expect(Headers.te[headers].valueOrNullIfInvalid, isNull);
        expect(() => headers.te, throwsInvalidHeader);
      });
    });

    group('when TE headers with invalid quality values are passed', () {
      test('then it should return null', () async {
        final headers = await getServerRequestHeaders(
          server: server,
          touchHeaders: (_) {},
          headers: {'te': 'trailers;q=abc, deflate, gzip'},
        );

        expect(Headers.te[headers].valueOrNullIfInvalid, isNull);
        expect(() => headers.te, throwsInvalidHeader);
      });
    });
  });
}
