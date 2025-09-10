import 'package:relic/relic.dart';
import 'package:test/test.dart';

import '../docs/strict_validation_docs.dart';
import '../headers_test_utils.dart';

/// Reference: https://developer.mozilla.org/en-US/docs/Web/HTTP/Headers/Origin
/// For more details on header validation behavior, see the [HeaderValidationDocs] class.
void main() {
  group(
    'Given an Origin header with validation',
    () {
      late RelicServer server;

      setUp(() async {
        server = await createServer();
      });

      tearDown(() => server.close());

      test(
        'when an empty Origin header is passed then the server responds '
        'with a bad request including a message that states the header value '
        'cannot be empty',
        () async {
          expect(
            getServerRequestHeaders(
              server: server,
              headers: {'origin': ''},
              touchHeaders: (final h) => h.origin,
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
        'when an Origin header with an invalid URI format is passed '
        'then the server responds with a bad request including a message that '
        'states the URI format is invalid',
        () async {
          expect(
            getServerRequestHeaders(
              server: server,
              headers: {'origin': 'h@ttp://example.com'},
              touchHeaders: (final h) => h.origin,
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
        'when an Origin header with an invalid port number is passed '
        'then the server responds with a bad request including a message that '
        'states the URI format is invalid',
        () async {
          expect(
            getServerRequestHeaders(
              server: server,
              headers: {'origin': 'http://example.com:test'},
              touchHeaders: (final h) => h.origin,
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
        'when an Origin header with an invalid origin format is passed '
        'then the server does not respond with a bad request if the headers '
        'is not actually used',
        () async {
          final headers = await getServerRequestHeaders(
            server: server,
            touchHeaders: (final _) {},
            headers: {'origin': 'http://example.com:test'},
          );

          expect(headers, isNotNull);
        },
      );

      test(
        'when a valid Origin header is passed then it should parse the URI correctly',
        () async {
          final headers = await getServerRequestHeaders(
            server: server,
            headers: {'origin': 'https://example.com'},
            touchHeaders: (final h) => h.origin,
          );

          expect(
            headers.origin,
            equals(Uri.parse('https://example.com')),
          );
        },
      );

      test(
        'when a valid Origin header is passed with a port number then it should parse the port number correctly',
        () async {
          final headers = await getServerRequestHeaders(
            server: server,
            headers: {'origin': 'https://example.com:8080'},
            touchHeaders: (final h) => h.origin,
          );

          expect(
            headers.origin?.port,
            equals(8080),
          );
        },
      );

      test(
        'when an Origin header with extra whitespace is passed then it should parse the URI correctly',
        () async {
          final headers = await getServerRequestHeaders(
            server: server,
            headers: {'origin': ' https://example.com '},
            touchHeaders: (final h) => h.origin,
          );

          expect(
            headers.origin,
            equals(Uri.parse('https://example.com')),
          );
        },
      );

      test(
        'when no Origin header is passed then it should return null',
        () async {
          final headers = await getServerRequestHeaders(
            server: server,
            headers: {},
            touchHeaders: (final h) => h.origin,
          );

          expect(headers.origin, isNull);
        },
      );
    },
  );

  group('Given an Origin header without validation', () {
    late RelicServer server;

    setUp(() async {
      server = await createServer();
    });

    tearDown(() => server.close());
    group('when an empty Origin header is passed', () {
      test(
        'then it should return null',
        () async {
          final headers = await getServerRequestHeaders(
            server: server,
            touchHeaders: (final _) {},
            headers: {'origin': ''},
          );
          expect(Headers.origin[headers].valueOrNullIfInvalid, isNull);
          expect(() => headers.origin, throwsInvalidHeader);
        },
      );
    });

    group('when an invalid Origin header is passed', () {
      test(
        'then it should return null',
        () async {
          final headers = await getServerRequestHeaders(
            server: server,
            touchHeaders: (final _) {},
            headers: {'origin': 'h@ttp://example.com'},
          );

          expect(Headers.origin[headers].valueOrNullIfInvalid, isNull);
          expect(() => headers.origin, throwsInvalidHeader);
        },
      );
    });
  });
}
