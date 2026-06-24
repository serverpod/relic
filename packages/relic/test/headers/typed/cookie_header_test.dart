import 'package:relic/relic.dart';
import 'package:test/test.dart';

import '../headers_test_utils.dart';

/// Reference: https://developer.mozilla.org/en-US/docs/Web/HTTP/Headers/Cookie
void main() {
  group('Given a Cookie header with validation', () {
    late RelicServer server;

    setUp(() async {
      server = await createServer();
    });

    tearDown(() => server.close());

    test(
      'when an empty Cookie header is passed then the server responds '
      'with a bad request including a message that states the header value cannot be empty',
      () async {
        expect(
          getServerRequestHeaders(
            server: server,
            touchHeaders: (final h) => h.cookie,
            headers: {'cookie': ''},
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
      'when a cookie with an invalid format (no "=") is present '
      'then it is skipped and the remaining valid cookies are still parsed',
      () async {
        // A single malformed cookie must not make the other cookies in the
        // same header unreadable.
        final headers = await getServerRequestHeaders(
          server: server,
          touchHeaders: (final h) => h.cookie,
          headers: {'cookie': 'sessionId=abc123; invalidCookie'},
        );

        expect(
          headers.cookie?.cookies.map((final c) => c.name).toList(),
          equals(['sessionId']),
        );
        expect(
          headers.cookie?.cookies.map((final c) => c.value).toList(),
          equals(['abc123']),
        );
      },
    );

    test(
      'when a cookie with an invalid name is present '
      'then it is skipped and the remaining valid cookies are still parsed',
      () async {
        final headers = await getServerRequestHeaders(
          server: server,
          touchHeaders: (final h) => h.cookie,
          headers: {'cookie': 'invalid name=abc123; userId=42'},
        );

        expect(
          headers.cookie?.cookies.map((final c) => c.name).toList(),
          equals(['userId']),
        );
        expect(
          headers.cookie?.cookies.map((final c) => c.value).toList(),
          equals(['42']),
        );
      },
    );

    test(
      'when a cookie with an invalid value is present '
      'then it is skipped and the remaining valid cookies are still parsed',
      () async {
        final headers = await getServerRequestHeaders(
          server: server,
          touchHeaders: (final h) => h.cookie,
          headers: {'cookie': 'sessionId=abc123; userId=42\x7F'},
        );

        expect(
          headers.cookie?.cookies.map((final c) => c.name).toList(),
          equals(['sessionId']),
        );
        expect(
          headers.cookie?.cookies.map((final c) => c.value).toList(),
          equals(['abc123']),
        );
      },
    );

    test(
      'when every cookie in the header is invalid '
      'then the server responds with a bad request stating there are no valid cookies',
      () async {
        expect(
          getServerRequestHeaders(
            server: server,
            touchHeaders: (final h) => h.cookie,
            headers: {'cookie': 'invalidCookie; another invalid'},
          ),
          throwsA(
            isA<BadRequestException>().having(
              (final e) => e.message,
              'message',
              contains('No valid cookies in Cookie header'),
            ),
          ),
        );
      },
    );

    test(
      'when a Cookie header with an invalid value is passed '
      'then the server does not respond with a bad request if the headers is not actually used',
      () async {
        final headers = await getServerRequestHeaders(
          server: server,
          touchHeaders: (_) {},
          headers: {'cookie': 'sessionId=abc123; userId=42\x7F'},
        );

        expect(headers, isNotNull);
      },
    );

    test('when a Cookie header carries a nameless `=value` segment '
        'then it is dropped and the named cookies are kept', () async {
      final headers = await getServerRequestHeaders(
        server: server,
        touchHeaders: (final h) => h.cookie,
        headers: {'cookie': '=abc123; userId=42'},
      );

      expect(
        headers.cookie?.cookies.map((final c) => c.name).toList(),
        equals(['userId']),
      );
      expect(
        headers.cookie?.cookies.map((final c) => c.value).toList(),
        equals(['42']),
      );
    });

    test('when a valid Cookie header is passed '
        'then it should parse the cookies correctly', () async {
      final headers = await getServerRequestHeaders(
        server: server,
        touchHeaders: (final h) => h.cookie,
        headers: {'cookie': 'sessionId=abc123; userId=42'},
      );

      expect(
        headers.cookie?.cookies.map((final c) => c.name).toList(),
        equals(['sessionId', 'userId']),
      );
      expect(
        headers.cookie?.cookies.map((final c) => c.value).toList(),
        equals(['abc123', '42']),
      );
    });

    test('when a Cookie header with encoded characters in the value is passed '
        'then it should parse correctly', () async {
      // Cookie values are opaque octets per RFC 6265; percent encoding is
      // an application-level convention and MUST NOT be decoded by the
      // server. The raw bytes round-trip through the parser unchanged.
      final headers = await getServerRequestHeaders(
        server: server,
        touchHeaders: (final h) => h.cookie,
        headers: {'cookie': 'sessionId=abc%20123; userId=42'},
      );

      expect(
        headers.cookie?.cookies.map((final c) => c.name).toList(),
        equals(['sessionId', 'userId']),
      );
      expect(
        headers.cookie?.cookies.map((final c) => c.value).toList(),
        equals(['abc%20123', '42']),
      );
    });

    test('when a valid Cookie header with duplicate cookies is passed '
        'then it should parse correctly and remove the duplicates', () async {
      final headers = await getServerRequestHeaders(
        server: server,
        touchHeaders: (final h) => h.cookie,
        headers: {'cookie': 'sessionId=abc123; userId=42; sessionId=abc123'},
      );

      expect(
        headers.cookie?.cookies.map((final c) => c.name).toList(),
        equals(['sessionId', 'userId']),
      );
      expect(
        headers.cookie?.cookies.map((final c) => c.value).toList(),
        equals(['abc123', '42']),
      );
    });

    test(
      'when a Cookie header has two cookies with the same name but different values '
      'then both are preserved and getCookie returns the first',
      () async {
        // RFC 6265 5.4 allows a Cookie header to carry duplicate cookie names
        // (e.g. a host-only cookie plus a Domain-scoped one); the server cannot
        // distinguish them from the header alone. The header must still parse,
        // since rejecting it would make an otherwise valid cookie unreadable.
        final headers = await getServerRequestHeaders(
          server: server,
          touchHeaders: (final h) => h.cookie,
          headers: {'cookie': 'sessionId=abc123; sessionId=xyz789'},
        );

        expect(
          headers.cookie?.cookies.map((final c) => c.name).toList(),
          equals(['sessionId', 'sessionId']),
        );
        expect(
          headers.cookie?.cookies.map((final c) => c.value).toList(),
          equals(['abc123', 'xyz789']),
        );
        expect(headers.cookie?.getCookie('sessionId')?.value, equals('abc123'));
      },
    );

    test('when a Cookie header is passed with extra whitespace '
        'then it should parse the cookies correctly', () async {
      final headers = await getServerRequestHeaders(
        server: server,
        touchHeaders: (final h) => h.cookie,
        headers: {'cookie': ' sessionId=abc123 ; userId=42 '},
      );

      expect(
        headers.cookie?.cookies.map((final c) => c.name).toList(),
        equals(['sessionId', 'userId']),
      );
      expect(
        headers.cookie?.cookies.map((final c) => c.value).toList(),
        equals(['abc123', '42']),
      );
    });
  });

  group('Given a Cookie header without validation', () {
    late RelicServer server;

    setUp(() async {
      server = await createServer();
    });

    tearDown(() => server.close());

    group('when parsing a fully invalid cookie header', () {
      test('when no cookie in the header is valid '
          'then it should return null', () async {
        // Only a header with no usable cookie at all is invalid; a header
        // with at least one valid cookie parses (the invalid ones are
        // skipped), so use an entirely invalid header here.
        final headers = await getServerRequestHeaders(
          server: server,
          touchHeaders: (_) {},
          headers: {'cookie': 'invalidCookie; another invalid'},
        );

        expect(Headers.cookie[headers].valueOrNullIfInvalid, isNull);
        expect(() => headers.cookie, throwsInvalidHeader);
      });
    });
  });
}
