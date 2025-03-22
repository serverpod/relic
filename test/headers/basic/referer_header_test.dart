import 'package:relic/relic.dart';
import 'package:test/test.dart';
import 'package:relic/src/headers/standard_headers_extensions.dart';

import '../headers_test_utils.dart';
import '../docs/strict_validation_docs.dart';

/// Reference: https://developer.mozilla.org/en-US/docs/Web/HTTP/Headers/Referer
/// About empty value test, check the [StrictValidationDocs] class for more details.
void main() {
  group(
    'Given a Referer header with the strict flag true',
    skip: 'drop strict mode',
    () {
      late RelicServer server;

      setUp(() async {
        server = await createServer(strictHeaders: true);
      });

      tearDown(() => server.close());

      test(
        'when a Referer header with an empty value is passed then the server '
        'responds with a bad request including a message that states the '
        'header value cannot be empty',
        () async {
          expect(
            () async => await getServerRequestHeaders(
              server: server,
              headers: {'referer': ''},
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
        'when a Referer header with an invalid URI is passed then the server '
        'responds with a bad request including a message that states the URI is '
        'invalid',
        () async {
          expect(
            () async => await getServerRequestHeaders(
              server: server,
              headers: {'referer': 'ht!tp://invalid-url'},
            ),
            throwsA(
              isA<BadRequestException>().having(
                (e) => e.message,
                'message',
                contains('Invalid URI'),
              ),
            ),
          );
        },
      );

      test(
        'when a Referer header with an invalid port number is passed '
        'then the server responds with a bad request including a message that '
        'states the URI format is invalid',
        () async {
          expect(
            () async => await getServerRequestHeaders(
              server: server,
              headers: {'referer': 'http://example.com:test'},
            ),
            throwsA(
              isA<BadRequestException>().having(
                (e) => e.message,
                'message',
                contains('Invalid URI format'),
              ),
            ),
          );
        },
      );

      test(
        'when a Referer header with an invalid value is passed '
        'then the server does not respond with a bad request if the headers '
        'is not actually used',
        () async {
          var headers = await getServerRequestHeaders(
            server: server,
            headers: {'referer': 'http://example.com:test'},
            eagerParseHeaders: false,
          );

          expect(headers, isNotNull);
        },
      );

      test(
        'when a Referer header with a valid URI is passed then it should parse '
        'correctly',
        () async {
          var headers = await getServerRequestHeaders(
            server: server,
            headers: {'referer': 'https://example.com/page'},
          );

          expect(
              headers.referer, equals(Uri.parse('https://example.com/page')));
        },
      );

      test(
        'when a Referer header with a port number is passed then it should parse '
        'the port number correctly',
        () async {
          var headers = await getServerRequestHeaders(
            server: server,
            headers: {'referer': 'https://example.com:8080'},
          );

          expect(
            headers.referer?.port,
            equals(8080),
          );
        },
      );

      test(
        'when a Referer header with extra whitespace is passed then it should '
        'parse the URI correctly',
        () async {
          var headers = await getServerRequestHeaders(
            server: server,
            headers: {'referer': ' https://example.com '},
          );

          expect(headers.referer, equals(Uri.parse('https://example.com')));
        },
      );

      test(
        'when no Referer header is passed then it should return null',
        () async {
          var headers = await getServerRequestHeaders(
            server: server,
            headers: {},
          );

          expect(headers.referer_.valueOrNullIfInvalid, isNull);
          expect(() => headers.referer, throwsA(isA<InvalidHeaderException>()));
        },
      );
    },
  );

  group('Given a Referer header with the strict flag false', () {
    late RelicServer server;

    setUp(() async {
      server = await createServer(strictHeaders: false);
    });

    tearDown(() => server.close());

    group('when an invalid Referer header is passed', () {
      test(
        'then it should return null',
        () async {
          var headers = await getServerRequestHeaders(
            server: server,
            headers: {'referer': 'ht!tp://invalid-url'},
          );

          expect(headers.referer_.valueOrNullIfInvalid, isNull);
          expect(() => headers.referer, throwsA(isA<InvalidHeaderException>()));
        },
      );

      test(
        'then it should be recorded in "failedHeadersToParse" field',
        skip: 'drop failedHeadersToParse',
        () async {
          var headers = await getServerRequestHeaders(
            server: server,
            headers: {'referer': 'ht!tp://invalid-url'},
          );

          expect(
            headers.failedHeadersToParse['referer'],
            equals(['ht!tp://invalid-url']),
          );
        },
      );
    });
  });
}
