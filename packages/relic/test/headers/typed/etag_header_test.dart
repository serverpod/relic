import 'package:relic/relic.dart';
import 'package:test/test.dart';

import '../docs/strict_validation_docs.dart';
import '../headers_test_utils.dart';

/// Reference: https://developer.mozilla.org/en-US/docs/Web/HTTP/Headers/ETag
/// For more details on header validation behavior, see the [HeaderValidationDocs] class.
void main() {
  group('Given an ETag header with validation', () {
    late RelicServer server;

    setUp(() async {
      server = await createServer();
    });

    tearDown(() => server.close());

    test('when an empty ETag header is passed then the server responds '
        'with a bad request including a message that states the header value '
        'cannot be empty', () async {
      expect(
        getServerRequestHeaders(
          server: server,
          touchHeaders: (final h) => h.etag,
          headers: {'etag': ''},
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

    test(
      'when an invalid ETag is passed then the server responds with a bad request '
      'including a message that states the ETag is invalid',
      () async {
        expect(
          getServerRequestHeaders(
            server: server,
            touchHeaders: (final h) => h.etag,
            headers: {'etag': '123456'},
          ),
          throwsA(
            isA<BadRequestException>().having(
              (final e) => e.message,
              'message',
              contains('Invalid format'),
            ),
          ),
        );
      },
    );

    test('when an ETag header with an invalid value is passed '
        'then the server does not respond with a bad request if the headers '
        'is not actually used', () async {
      final headers = await getServerRequestHeaders(
        server: server,
        touchHeaders: (_) {},
        headers: {'etag': '123456'},
      );

      expect(headers, isNotNull);
    });

    test(
      'when a valid strong ETag is passed then it should parse correctly',
      () async {
        final headers = await getServerRequestHeaders(
          server: server,
          touchHeaders: (final h) => h.etag,
          headers: {'etag': '"123456"'},
        );

        expect(headers.etag?.value, equals('123456'));
        expect(headers.etag?.isWeak, isFalse);
      },
    );

    test(
      'when a valid weak ETag is passed then it should parse correctly',
      () async {
        final headers = await getServerRequestHeaders(
          server: server,
          touchHeaders: (final h) => h.etag,
          headers: {'etag': 'W/"123456"'},
        );

        expect(headers.etag?.value, equals('123456'));
        expect(headers.etag?.isWeak, isTrue);
      },
    );

    test('when no ETag header is passed then it should return null', () async {
      final headers = await getServerRequestHeaders(
        server: server,
        touchHeaders: (final h) => h.etag,
        headers: {},
      );

      expect(headers.etag, isNull);
    });
  });

  group('Given an ETag header without validation', () {
    late RelicServer server;

    setUp(() async {
      server = await createServer();
    });

    tearDown(() => server.close());

    group('when an invalid ETag header is passed', () {
      test('then it should return null', () async {
        final headers = await getServerRequestHeaders(
          server: server,
          touchHeaders: (_) {},
          headers: {'etag': '123456'},
        );

        expect(Headers.etag[headers].valueOrNullIfInvalid, isNull);
        expect(() => headers.etag, throwsInvalidHeader);
      });
    });
  });
}
