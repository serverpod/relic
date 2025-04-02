import 'package:relic/relic.dart';
import 'package:http_parser/http_parser.dart';
import 'package:test/test.dart';
import 'package:relic/src/headers/standard_headers_extensions.dart';

import '../headers_test_utils.dart';
import '../docs/strict_validation_docs.dart';

/// Reference: https://developer.mozilla.org/en-US/docs/Web/HTTP/Headers/Retry-After
/// About empty value test, check the [StrictValidationDocs] class for more details.
void main() {
  group('Given a Retry-After header with the strict flag true', () {
    late RelicServer server;

    setUp(() async {
      server = await createServer(strictHeaders: true);
    });

    tearDown(() => server.close());

    test(
      'when an empty Retry-After header is passed then the server should respond with a bad request '
      'including a message that states the value cannot be empty',
      () async {
        expect(
          getServerRequestHeaders(
            server: server,
            touchHeaders: (h) => h.retryAfter,
            headers: {'retry-after': ''},
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
      'when a Retry-After header with an invalid value is passed '
      'then the server does not respond with a bad request if the headers '
      'is not actually used',
      () async {
        var headers = await getServerRequestHeaders(
          server: server,
          touchHeaders: (_) {},
          headers: {'retry-after': 'invalid'},
        );

        expect(headers, isNotNull);
      },
    );

    group('when the header contains a delay in seconds', () {
      test('then it should parse a valid positive integer correctly', () async {
        var headers = await getServerRequestHeaders(
          server: server,
          touchHeaders: (h) => h.retryAfter,
          headers: {'retry-after': '120'},
        );

        expect(headers.retryAfter?.delay, equals(120));
      });

      test('then it should parse a value with whitespace correctly', () async {
        var headers = await getServerRequestHeaders(
          server: server,
          touchHeaders: (h) => h.retryAfter,
          headers: {'retry-after': ' 120 '},
        );

        expect(headers.retryAfter?.delay, equals(120));
      });

      test('then it should throw an error on a negative value', () async {
        expect(
          getServerRequestHeaders(
            server: server,
            touchHeaders: (h) => h.retryAfter,
            headers: {'retry-after': '-120'},
          ),
          throwsA(isA<BadRequestException>().having(
            (e) => e.message,
            'message',
            contains('Delay cannot be negative'),
          )),
        );
      });

      test('then it should throw an error on a non-integer value', () async {
        expect(
          getServerRequestHeaders(
            server: server,
            touchHeaders: (h) => h.retryAfter,
            headers: {'retry-after': '120.5'},
          ),
          throwsA(isA<BadRequestException>().having(
            (e) => e.message,
            'message',
            contains('Invalid date format'),
          )),
        );
      });
    });

    group('when the header contains an HTTP date', () {
      test('then it should parse a valid date correctly', () async {
        var headers = await getServerRequestHeaders(
          server: server,
          touchHeaders: (h) => h.retryAfter,
          headers: {'retry-after': 'Wed, 21 Oct 2015 07:28:00 GMT'},
        );

        expect(
          headers.retryAfter?.date,
          equals(parseHttpDate('Wed, 21 Oct 2015 07:28:00 GMT')),
        );
      });

      test('then it should parse a date with whitespace correctly', () async {
        var headers = await getServerRequestHeaders(
          server: server,
          touchHeaders: (h) => h.retryAfter,
          headers: {'retry-after': ' Wed, 21 Oct 2015 07:28:00 GMT '},
        );

        expect(
          headers.retryAfter?.date,
          equals(parseHttpDate('Wed, 21 Oct 2015 07:28:00 GMT')),
        );
      });

      test('then it should throw an error on an invalid date format', () async {
        expect(
          getServerRequestHeaders(
            server: server,
            touchHeaders: (h) => h.retryAfter,
            headers: {'retry-after': '2015-10-21'},
          ),
          throwsA(isA<BadRequestException>().having(
            (e) => e.message,
            'message',
            contains('Invalid date format'),
          )),
        );
      });
    });

    test(
      'when no Retry-After header is passed then it should return null',
      () async {
        var headers = await getServerRequestHeaders(
          server: server,
          touchHeaders: (h) => h.retryAfter,
          headers: {},
        );

        expect(headers.retryAfter, isNull);
      },
    );
  });

  group('Given a Retry-After header with the strict flag false', () {
    late RelicServer server;

    setUp(() async {
      server = await createServer(strictHeaders: false);
    });

    tearDown(() => server.close());

    test(
      'when an invalid header is passed then it should return null',
      () async {
        var headers = await getServerRequestHeaders(
          server: server,
          touchHeaders: (_) {},
          headers: {'retry-after': 'invalid'},
        );

        expect(Headers.retryAfter[headers].valueOrNullIfInvalid, isNull);
        expect(() => headers.retryAfter, throwsInvalidHeader);
      },
    );
  });
}
