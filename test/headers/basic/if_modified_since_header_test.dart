import 'package:relic/relic.dart';
import 'package:http_parser/http_parser.dart';
import 'package:test/test.dart';
import 'package:relic/src/headers/standard_headers_extensions.dart';
import '../headers_test_utils.dart';
import '../docs/strict_validation_docs.dart';

/// Reference: https://developer.mozilla.org/en-US/docs/Web/HTTP/Headers/If-Modified-Since
/// About empty value test, check the [StrictValidationDocs] class for more details.
void main() {
  group('Given an If-Modified-Since header with the strict flag true',
      skip: 'todo: drop strict mode', () {
    late RelicServer server;

    setUp(() async {
      server = await createServer(strictHeaders: true);
    });

    tearDown(() => server.close());

    test(
      'when an empty If-Modified-Since header is passed then the server responds '
      'with a bad request including a message that states the header value '
      'cannot be empty',
      () async {
        expect(
          () async => await getServerRequestHeaders(
            server: server,
            headers: {'if-modified-since': ''},
          ),
          throwsA(
            isA<BadRequestException>().having(
              (e) => e.message,
              'message',
              contains('Value cannot be empty'),
            ),
          ),
        );
      },
    );

    test(
      'when an If-Modified-Since header with an invalid date format is passed '
      'then the server responds with a bad request including a message that '
      'states the date format is invalid',
      () async {
        expect(
          () async => await getServerRequestHeaders(
            server: server,
            headers: {'if-modified-since': 'invalid-date-format'},
          ),
          throwsA(
            isA<BadRequestException>().having(
              (e) => e.message,
              'message',
              contains('Invalid date format'),
            ),
          ),
        );
      },
    );

    test(
      'when an If-Modified-Since header with an invalid date format is passed '
      'then the server does not respond with a bad request if the headers '
      'is not actually used',
      () async {
        var headers = await getServerRequestHeaders(
          server: server,
          headers: {'if-modified-since': 'invalid-date-format'},
          eagerParseHeaders: false,
        );

        expect(headers, isNotNull);
      },
    );

    test(
      'when a valid If-Modified-Since header is passed then it should parse the '
      'date correctly',
      () async {
        var headers = await getServerRequestHeaders(
          server: server,
          headers: {'if-modified-since': 'Wed, 21 Oct 2015 07:28:00 GMT'},
        );

        expect(
          headers.ifModifiedSince,
          equals(parseHttpDate('Wed, 21 Oct 2015 07:28:00 GMT')),
        );
      },
    );

    test(
      'when an If-Modified-Since header with extra whitespace is passed then it should parse the date correctly',
      () async {
        var headers = await getServerRequestHeaders(
          server: server,
          headers: {'if-modified-since': ' Wed, 21 Oct 2015 07:28:00 GMT '},
        );

        expect(
          headers.ifModifiedSince,
          equals(parseHttpDate('Wed, 21 Oct 2015 07:28:00 GMT')),
        );
      },
    );

    test(
      'when no If-Modified-Since header is passed then it should return null',
      () async {
        var headers = await getServerRequestHeaders(
          server: server,
          headers: {},
        );

        expect(headers.ifModifiedSince_.valueOrNullIfInvalid, isNull);
        expect(() => headers.ifModifiedSince,
            throwsA(isA<InvalidHeaderException>()));
      },
    );
  });

  group('Given an If-Modified-Since header with the strict flag false', () {
    late RelicServer server;

    setUp(() async {
      server = await createServer(strictHeaders: false);
    });

    tearDown(() => server.close());

    group('when an empty If-Modified-Since header is passed', () {
      test(
        'then it should return null',
        () async {
          var headers = await getServerRequestHeaders(
            server: server,
            headers: {'if-modified-since': ''},
          );

          expect(headers.ifModifiedSince_.valueOrNullIfInvalid, isNull);
          expect(() => headers.ifModifiedSince,
              throwsA(isA<InvalidHeaderException>()));
        },
      );
    });

    group('when an invalid If-Modified-Since header is passed', () {
      test(
        'then it should return null',
        () async {
          var headers = await getServerRequestHeaders(
            server: server,
            headers: {'if-modified-since': 'invalid-date-format'},
          );

          expect(headers.ifModifiedSince_.valueOrNullIfInvalid, isNull);
          expect(() => headers.ifModifiedSince,
              throwsA(isA<InvalidHeaderException>()));
        },
      );
    });
  });
}
