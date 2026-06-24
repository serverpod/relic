import 'package:relic/relic.dart';
import 'package:test/test.dart';

import '../headers_test_utils.dart';

/// Reference: https://developer.mozilla.org/en-US/docs/Web/HTTP/Headers/Cookie
void main() {
  late RelicServer server;

  setUp(() async {
    server = await createServer();
  });

  tearDown(() => server.close());

  group('Given an empty Cookie header,', () {
    test(
      'when it is accessed '
      'then the server responds with a bad request stating the value cannot be empty',
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
  });

  group('Given a Cookie header with a malformed-format cookie (no "="),', () {
    test(
      'when it is accessed '
      'then the malformed cookie is skipped and the valid cookies remain',
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
  });

  group('Given a Cookie header with an invalid cookie name,', () {
    test(
      'when it is accessed '
      'then the invalid cookie is skipped and the valid cookies remain',
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
  });

  group('Given a Cookie header with an invalid cookie value,', () {
    test(
      'when it is accessed '
      'then the invalid cookie is skipped and the valid cookies remain',
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
  });

  group('Given a Cookie header where every cookie is invalid,', () {
    test(
      'when it is accessed '
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
      'when it is not accessed '
      'then no error is raised (the header is parsed lazily) and the tolerant accessor yields null',
      () async {
        // Parsing is lazy: an untouched header raises nothing, even when every
        // cookie in it is invalid. The tolerant accessor yields null and a
        // direct access throws.
        final headers = await getServerRequestHeaders(
          server: server,
          touchHeaders: (_) {},
          headers: {'cookie': 'invalidCookie; another invalid'},
        );

        expect(headers, isNotNull);
        expect(Headers.cookie[headers].valueOrNullIfInvalid, isNull);
        expect(() => headers.cookie, throwsInvalidHeader);
      },
    );
  });

  group('Given a Cookie header with a nameless `=value` segment,', () {
    test(
      'when it is accessed '
      'then the nameless segment is dropped and the named cookies are kept',
      () async {
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
      },
    );
  });

  group('Given a valid Cookie header,', () {
    test('when it is accessed '
        'then the cookies are parsed in order', () async {
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
  });

  group(
    'Given a Cookie header with percent-encoded characters in the value,',
    () {
      test(
        'when it is accessed '
        'then the raw bytes round-trip unchanged (no percent-decoding)',
        () async {
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
        },
      );
    },
  );

  group('Given a Cookie header with byte-identical duplicate cookies,', () {
    test(
      'when it is accessed '
      'then every cookie is preserved (duplicates are not collapsed)',
      () async {
        // RFC 6265 5.4 permits repeated cookies; the server cannot distinguish
        // them from the header alone, so getCookies must report the true count
        // rather than silently deduping byte-identical segments.
        final headers = await getServerRequestHeaders(
          server: server,
          touchHeaders: (final h) => h.cookie,
          headers: {'cookie': 'sessionId=abc123; userId=42; sessionId=abc123'},
        );

        expect(
          headers.cookie?.cookies.map((final c) => c.name).toList(),
          equals(['sessionId', 'userId', 'sessionId']),
        );
        expect(
          headers.cookie?.cookies.map((final c) => c.value).toList(),
          equals(['abc123', '42', 'abc123']),
        );
      },
    );
  });

  group(
    'Given a Cookie header with same-name cookies of different values,',
    () {
      test('when it is accessed '
          'then both are preserved and getCookie returns the first', () async {
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
      });
    },
  );

  group('Given a Cookie header with extra whitespace,', () {
    test('when it is accessed '
        'then the surrounding whitespace is trimmed', () async {
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
}
