import 'package:http_parser/http_parser.dart';
import 'package:relic/relic.dart';
import 'package:test/test.dart';

import '../docs/strict_validation_docs.dart';
import '../headers_test_utils.dart';

/// Reference: https://developer.mozilla.org/en-US/docs/Web/HTTP/Headers/If-Range
/// About empty value test, check the [StrictValidationDocs] class for more details.
void main() {
  group('Given an If-Range header with the strict flag true', () {
    late RelicServer server;

    setUp(() async {
      server = await createServer();
    });

    tearDown(() => server.close());

    test(
      'when an empty If-Range header is passed then the server responds '
      'with a bad request including a message that states the header value '
      'cannot be empty',
      () async {
        expect(
          getServerRequestHeaders(
            server: server,
            touchHeaders: (final h) => h.ifRange,
            headers: {'if-range': ''},
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
      'when an invalid ETag format is passed then the server responds with a '
      'bad request including a message that states the ETag format is invalid',
      () async {
        expect(
          getServerRequestHeaders(
            server: server,
            touchHeaders: (final h) => h.ifRange,
            headers: {'if-range': 'invalid-etag'},
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

    test(
      'when an If-Range header with an invalid value is passed '
      'then the server does not respond with a bad request if the headers '
      'is not actually used',
      () async {
        final headers = await getServerRequestHeaders(
          server: server,
          touchHeaders: (final _) {},
          headers: {'if-range': 'invalid-value'},
        );

        expect(headers, isNotNull);
      },
    );

    test(
      'when an If-Range header with a valid ETag is passed then it should parse correctly',
      () async {
        final headers = await getServerRequestHeaders(
          server: server,
          touchHeaders: (final h) => h.ifRange,
          headers: {'if-range': '"123456"'},
        );

        expect(headers.ifRange?.etag?.value, equals('123456'));
        expect(headers.ifRange?.etag?.isWeak, isFalse);
        expect(headers.ifRange?.lastModified, isNull);
      },
    );

    test(
      'when an If-Range header with a weak ETag is passed then it should parse correctly',
      () async {
        final headers = await getServerRequestHeaders(
          server: server,
          touchHeaders: (final h) => h.ifRange,
          headers: {'if-range': 'W/"123456"'},
        );

        expect(headers.ifRange?.etag?.value, equals('123456'));
        expect(headers.ifRange?.etag?.isWeak, isTrue);
        expect(headers.ifRange?.lastModified, isNull);
      },
    );

    test(
      'when an If-Range header with a valid HTTP date is passed then it should parse correctly',
      () async {
        final headers = await getServerRequestHeaders(
          server: server,
          touchHeaders: (final h) => h.ifRange,
          headers: {'if-range': 'Wed, 21 Oct 2015 07:28:00 GMT'},
        );

        expect(headers.ifRange?.etag, isNull);
        expect(
          headers.ifRange?.lastModified?.toUtc(),
          equals(parseHttpDate('Wed, 21 Oct 2015 07:28:00 GMT')),
        );
      },
    );

    test(
      'when no If-Range header is passed then it should default to null',
      () async {
        final headers = await getServerRequestHeaders(
          server: server,
          touchHeaders: (final h) => h.ifRange,
          headers: {},
        );

        expect(headers.ifRange, isNull);
      },
    );
  });

  group('Given an If-Range header with the strict flag false', () {
    late RelicServer server;

    setUp(() async {
      server = await createServer();
    });

    tearDown(() => server.close());

    group('when an invalid If-Range header is passed', () {
      test(
        'then it should return null',
        () async {
          final headers = await getServerRequestHeaders(
            server: server,
            touchHeaders: (final _) {},
            headers: {'if-range': 'invalid-value'},
          );

          expect(Headers.ifRange[headers].valueOrNullIfInvalid, isNull);
          expect(() => headers.ifRange, throwsInvalidHeader);
        },
      );
    });
  });
}
