import 'package:relic/relic.dart';
import 'package:test/test.dart';

import '../docs/strict_validation_docs.dart';
import '../headers_test_utils.dart';

/// Reference: https://developer.mozilla.org/en-US/docs/Web/HTTP/Headers/Accept-Encoding
/// For more details on header validation behavior, see the [HeaderValidationDocs] class.
void main() {
  group('Given an Accept-Encoding header with validation', () {
    late RelicServer server;

    setUp(() async {
      server = await createServer();
    });

    tearDown(() => server.close());

    test(
      'when an empty Accept-Encoding header is passed then the server responds '
      'with a bad request including a message that states the header value cannot be empty',
      () async {
        expect(
          getServerRequestHeaders(
            server: server,
            headers: {'accept-encoding': ''},
            touchHeaders: (final h) => h.acceptEncoding,
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
      'when an Accept-Encoding header with invalid quality values is passed '
      'then the server responds with a bad request including a message that '
      'states the quality value is invalid',
      () async {
        expect(
          getServerRequestHeaders(
            server: server,
            headers: {'accept-encoding': 'gzip;q=abc'},
            touchHeaders: (final h) => h.acceptEncoding,
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
      'when an Accept-Encoding header with wildcard (*) and other encodings is '
      'passed then the server responds with a bad request including a message '
      'that states the wildcard (*) cannot be used with other values',
      () async {
        expect(
          getServerRequestHeaders(
            server: server,
            headers: {'accept-encoding': '*, gzip'},
            touchHeaders: (final h) => h.acceptEncoding,
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
      'when an Accept-Encoding header with empty encoding is passed then '
      'the server responds with a bad request including a message that '
      'states the encoding is invalid',
      () async {
        expect(
          getServerRequestHeaders(
            server: server,
            headers: {'accept-encoding': ';q=0.5'},
            touchHeaders: (final h) => h.acceptEncoding,
          ),
          throwsA(
            isA<BadRequestException>().having(
              (final e) => e.message,
              'message',
              contains('Invalid encoding'),
            ),
          ),
        );
      },
    );

    test(
      'when an Accept-Encoding header with an invalid value is passed '
      'then the server does not respond with a bad request if the headers '
      'is not actually used',
      () async {
        final headers = await getServerRequestHeaders(
          server: server,
          touchHeaders: (final _) {},
          headers: {'accept-encoding': ';q=0.5'},
        );

        expect(headers, isNotNull);
      },
    );

    test(
      'when an Accept-Encoding header is passed then it should parse the encoding correctly',
      () async {
        final headers = await getServerRequestHeaders(
          server: server,
          headers: {'accept-encoding': 'gzip'},
          touchHeaders: (final h) => h.acceptEncoding,
        );

        expect(
          headers.acceptEncoding?.encodings
              .map((final e) => e.encoding)
              .toList(),
          equals(['gzip']),
        );
      },
    );

    test(
      'when an Accept-Encoding header is passed without quality then the '
      'default quality value should be set',
      () async {
        final headers = await getServerRequestHeaders(
          server: server,
          headers: {'accept-encoding': 'gzip'},
          touchHeaders: (final h) => h.acceptEncoding,
        );

        expect(
          headers.acceptEncoding?.encodings
              .map((final e) => e.quality)
              .toList(),
          equals([1.0]),
        );
      },
    );

    test(
      'when an Accept-Encoding header is passed with quality then the '
      'quality value should be set',
      () async {
        final headers = await getServerRequestHeaders(
          server: server,
          headers: {'accept-encoding': 'gzip;q=0.5'},
          touchHeaders: (final h) => h.acceptEncoding,
        );

        expect(
          headers.acceptEncoding?.encodings
              .map((final e) => e.quality)
              .toList(),
          equals([0.5]),
        );
      },
    );

    test(
      'when a mixed case Accept-Encoding header is passed then it should parse '
      'the encoding correctly',
      () async {
        final headers = await getServerRequestHeaders(
          server: server,
          headers: {'accept-encoding': 'GZip'},
          touchHeaders: (final h) => h.acceptEncoding,
        );

        expect(
          headers.acceptEncoding?.encodings
              .map((final e) => e.encoding)
              .toList(),
          equals(['gzip']),
        );
      },
    );

    test(
      'when an Accept-Encoding header with wildcard (*) is passed then it should '
      'parse correctly',
      () async {
        final headers = await getServerRequestHeaders(
          server: server,
          headers: {'accept-encoding': '*'},
          touchHeaders: (final h) => h.acceptEncoding,
        );

        expect(headers.acceptEncoding?.isWildcard, isTrue);
        expect(headers.acceptEncoding?.encodings, isEmpty);
      },
    );

    test(
      'when an Accept-Encoding header with wildcard (*) and quality value is '
      'passed then it should parse the encoding correctly',
      () async {
        final headers = await getServerRequestHeaders(
          server: server,
          headers: {'accept-encoding': '*;q=0.5'},
          touchHeaders: (final h) => h.acceptEncoding,
        );

        expect(
          headers.acceptEncoding?.encodings
              .map((final e) => e.encoding)
              .toList(),
          equals(['*']),
        );
        expect(
          headers.acceptEncoding?.encodings
              .map((final e) => e.quality)
              .toList(),
          equals([0.5]),
        );
      },
    );

    test(
      'when no Accept-Encoding header is passed then it should default to gzip',
      () async {
        final headers = await getServerRequestHeaders(
          server: server,
          headers: {},
          touchHeaders: (final h) => h.acceptEncoding,
        );

        expect(
          headers.acceptEncoding?.encodings
              .map((final e) => e.encoding)
              .toList(),
          equals(['gzip']),
        );
        expect(
          headers.acceptEncoding?.encodings
              .map((final e) => e.quality)
              .toList(),
          equals([1.0]),
        );
      },
    );

    group('when multiple Accept-Encoding headers are passed', () {
      test(
        'then they should parse the encodings correctly',
        () async {
          final headers = await getServerRequestHeaders(
            server: server,
            headers: {'accept-encoding': 'gzip, deflate, br'},
            touchHeaders: (final h) => h.acceptEncoding,
          );

          expect(
            headers.acceptEncoding?.encodings
                .map((final e) => e.encoding)
                .toList(),
            equals(['gzip', 'deflate', 'br']),
          );
        },
      );

      test(
        'with quality values then they should parse the encodings correctly',
        () async {
          final headers = await getServerRequestHeaders(
            server: server,
            headers: {'accept-encoding': 'gzip;q=1.0, deflate;q=0.5, br;q=0.8'},
            touchHeaders: (final h) => h.acceptEncoding,
          );

          expect(
            headers.acceptEncoding?.encodings
                .map((final e) => e.encoding)
                .toList(),
            equals(['gzip', 'deflate', 'br']),
          );
        },
      );

      test(
        'with quality values then they should parse the qualities correctly',
        () async {
          final headers = await getServerRequestHeaders(
            server: server,
            headers: {'accept-encoding': 'gzip;q=1.0, deflate;q=0.5, br;q=0.8'},
            touchHeaders: (final h) => h.acceptEncoding,
          );

          expect(
            headers.acceptEncoding?.encodings
                .map((final e) => e.quality)
                .toList(),
            equals([1.0, 0.5, 0.8]),
          );
        },
      );

      test(
        'with duplicated values then it should remove duplicates and parse '
        'the encodings correctly',
        () async {
          final headers = await getServerRequestHeaders(
            server: server,
            headers: {'accept-encoding': 'gzip, gzip, deflate, br'},
            touchHeaders: (final h) => h.acceptEncoding,
          );

          expect(
            headers.acceptEncoding?.encodings
                .map((final e) => e.encoding)
                .toList(),
            equals(['gzip', 'deflate', 'br']),
          );
        },
      );

      test(
        'with extra whitespace then it should parse the encodings correctly',
        () async {
          final headers = await getServerRequestHeaders(
            server: server,
            headers: {'accept-encoding': ' gzip , deflate , br '},
            touchHeaders: (final h) => h.acceptEncoding,
          );

          expect(
            headers.acceptEncoding?.encodings
                .map((final e) => e.encoding)
                .toList(),
            equals(['gzip', 'deflate', 'br']),
          );
        },
      );
    });
  });

  group('Given an Accept-Encoding header without validation', () {
    late RelicServer server;

    setUp(() async {
      server = await createServer();
    });

    tearDown(() => server.close());

    group('when an invalid Accept-Encoding header is passed', () {
      test(
        'then it should return null',
        () async {
          final headers = await getServerRequestHeaders(
            server: server,
            touchHeaders: (final _) {},
            headers: {'accept-encoding': ''},
          );

          expect(Headers.acceptEncoding[headers].valueOrNullIfInvalid, isNull);
          expect(() => headers.acceptEncoding, throwsInvalidHeader);
        },
      );
    });

    group('when Accept-Encoding headers with invalid quality values are passed',
        () {
      test(
        'then it should return null',
        () async {
          final headers = await getServerRequestHeaders(
            server: server,
            touchHeaders: (final _) {},
            headers: {'accept-encoding': 'gzip;q=abc, deflate, br'},
          );

          expect(Headers.acceptEncoding[headers].valueOrNullIfInvalid, isNull);
          expect(() => headers.acceptEncoding, throwsInvalidHeader);
        },
      );
    });
  });
}
