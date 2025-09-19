import 'package:relic/relic.dart';
import 'package:test/test.dart';

import '../docs/strict_validation_docs.dart';
import '../headers_test_utils.dart';

/// Reference: https://developer.mozilla.org/en-US/docs/Web/HTTP/Headers/Referer
/// For more details on header validation behavior, see the [HeaderValidationDocs] class.
void main() {
  group(
    'Given a Referer header with validation',
    () {
      late RelicServer server;

      setUp(() async {
        server = await createServer();
      });

      tearDown(() => server.close());

      test(
        'when a Referer header with an empty value is passed then the server '
        'responds with a bad request including a message that states the '
        'header value cannot be empty',
        () async {
          expect(
            getServerRequestHeaders(
              server: server,
              headers: {'referer': ''},
              touchHeaders: (final h) => h.referer,
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
        'when a Referer header with an invalid URI is passed then the server '
        'responds with a bad request including a message that states the URI is '
        'invalid',
        () async {
          expect(
            getServerRequestHeaders(
              server: server,
              headers: {'referer': 'ht!tp://invalid-url'},
              touchHeaders: (final h) => h.referer,
            ),
            throwsA(
              isA<BadRequestException>().having(
                (final e) => e.message,
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
            getServerRequestHeaders(
              server: server,
              headers: {'referer': 'http://example.com:test'},
              touchHeaders: (final h) => h.referer,
            ),
            throwsA(
              isA<BadRequestException>().having(
                (final e) => e.message,
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
          final headers = await getServerRequestHeaders(
            server: server,
            touchHeaders: (final _) {},
            headers: {'referer': 'http://example.com:test'},
          );

          expect(headers, isNotNull);
        },
      );

      test(
        'when a Referer header with a valid URI is passed then it should parse '
        'correctly',
        () async {
          final headers = await getServerRequestHeaders(
            server: server,
            headers: {'referer': 'https://example.com/page'},
            touchHeaders: (final h) => h.referer,
          );

          expect(
              headers.referer, equals(Uri.parse('https://example.com/page')));
        },
      );

      test(
        'when a Referer header with a port number is passed then it should parse '
        'the port number correctly',
        () async {
          final headers = await getServerRequestHeaders(
            server: server,
            headers: {'referer': 'https://example.com:8080'},
            touchHeaders: (final h) => h.referer,
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
          final headers = await getServerRequestHeaders(
            server: server,
            headers: {'referer': ' https://example.com '},
            touchHeaders: (final h) => h.referer,
          );

          expect(headers.referer, equals(Uri.parse('https://example.com')));
        },
      );

      test(
        'when no Referer header is passed then it should return null',
        () async {
          final headers = await getServerRequestHeaders(
            server: server,
            headers: {},
            touchHeaders: (final h) => h.referer,
          );

          expect(headers.referer, isNull);
        },
      );
    },
  );

  group('Given a Referer header without validation', () {
    late RelicServer server;

    setUp(() async {
      server = await createServer();
    });

    tearDown(() => server.close());

    group('when an invalid Referer header is passed', () {
      test(
        'then it should return null',
        () async {
          final headers = await getServerRequestHeaders(
            server: server,
            touchHeaders: (final _) {},
            headers: {'referer': 'ht!tp://invalid-url'},
          );

          expect(Headers.referer[headers].valueOrNullIfInvalid, isNull);
          expect(() => headers.referer, throwsInvalidHeader);
        },
      );
    });
  });
}
