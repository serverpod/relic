import 'package:relic/relic.dart';
import 'package:relic/src/headers/standard_headers_extensions.dart';
import 'package:test/test.dart';

import '../docs/strict_validation_docs.dart';
import '../headers_test_utils.dart';

/// Reference: https://developer.mozilla.org/en-US/docs/Web/HTTP/Headers/Host
/// About empty value test, check the [StrictValidationDocs] class for more details.
void main() {
  group(
    'Given a Host header with the strict flag true',
    () {
      late RelicServer server;

      setUp(() async {
        server = await createServer(strictHeaders: true);
      });

      tearDown(() => server.close());
      test(
        'when an empty Host header is passed then the server responds '
        'with a bad request including a message that states the header value '
        'cannot be empty',
        () async {
          expect(
            getServerRequestHeaders(
              server: server,
              headers: {'host': ''},
              touchHeaders: (final h) => h.host,
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
        'when a Host header with an invalid URI format is passed '
        'then the server responds with a bad request including a message that '
        'states the URI format is invalid',
        () async {
          expect(
            getServerRequestHeaders(
              server: server,
              headers: {'host': 'h@ttp://example.com'},
              touchHeaders: (final h) => h.host,
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
        'when a Host header with an invalid port number is passed '
        'then the server responds with a bad request including a message that '
        'states the URI format is invalid',
        () async {
          expect(
            getServerRequestHeaders(
              server: server,
              headers: {'host': 'http://example.com:test'},
              touchHeaders: (final h) => h.host,
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
        'when a Host header with an invalid value is passed '
        'then the server does not respond with a bad request if the headers '
        'is not actually used',
        () async {
          final headers = await getServerRequestHeaders(
            server: server,
            touchHeaders: (final _) {},
            headers: {'host': 'http://example.com:test'},
          );

          expect(headers, isNotNull);
        },
      );

      test(
        'when a valid Host header is passed then it should parse the URI correctly',
        () async {
          final headers = await getServerRequestHeaders(
            server: server,
            headers: {'host': 'https://example.com'},
            touchHeaders: (final h) => h.host,
          );

          expect(headers.host, equals(Uri.parse('https://example.com')));
        },
      );

      test(
        'when a Host header with a port number is passed then it should parse '
        'the port number correctly',
        () async {
          final headers = await getServerRequestHeaders(
            server: server,
            headers: {'host': 'https://example.com:8080'},
            touchHeaders: (final h) => h.host,
          );

          expect(
            headers.host?.port,
            equals(8080),
          );
        },
      );

      test(
        'when a Host header with extra whitespace is passed then it should parse the URI correctly',
        () async {
          final headers = await getServerRequestHeaders(
            server: server,
            headers: {'host': ' https://example.com '},
            touchHeaders: (final h) => h.host,
          );

          expect(headers.host, equals(Uri.parse('https://example.com')));
        },
      );

      test(
        'when no Host header is passed then it should default to machine address',
        () async {
          final headers = await getServerRequestHeaders(
            server: server,
            headers: {},
            touchHeaders: (final h) => h.host,
          );

          expect(headers.host, isNotNull);
          expect(headers.host, isA<Uri>());
        },
      );
    },
  );

  group('Given a Host header with the strict flag false', () {
    late RelicServer server;

    setUp(() async {
      server = await createServer(strictHeaders: false);
    });

    tearDown(() => server.close());

    group('when an invalid Host header is passed', () {
      test(
        'then it should return null',
        () async {
          final headers = await getServerRequestHeaders(
            server: server,
            touchHeaders: (final _) {},
            headers: {'host': 'h@ttp://example.com'},
          );

          expect(Headers.host[headers].valueOrNullIfInvalid, isNull);
          expect(() => headers.host, throwsInvalidHeader);
        },
      );
    });

    test(
      'when no Host header is passed then it should default to machine address',
      () async {
        final headers = await getServerRequestHeaders(
          server: server,
          headers: {},
          touchHeaders: (final h) => h.host,
        );

        expect(headers.host, isNotNull);
        expect(headers.host, isA<Uri>());
      },
    );
  });
}
