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
      'when a Cookie header with invalid format is passed then the server responds '
      'with a bad request including a message that states the cookie format is invalid',
      () async {
        expect(
          getServerRequestHeaders(
            server: server,
            touchHeaders: (final h) => h.cookie,
            headers: {'cookie': 'sessionId=abc123; invalidCookie'},
          ),
          throwsA(
            isA<BadRequestException>().having(
              (final e) => e.message,
              'message',
              contains('Invalid cookie format'),
            ),
          ),
        );
      },
    );

    test(
      'when a Cookie header with an invalid name is passed then the server responds '
      'with a bad request including a message that states the cookie name is invalid',
      () async {
        expect(
          getServerRequestHeaders(
            server: server,
            touchHeaders: (final h) => h.cookie,
            headers: {'cookie': 'invalid name=abc123; userId=42'},
          ),
          throwsA(
            isA<BadRequestException>().having(
              (final e) => e.message,
              'message',
              contains('Invalid cookie name'),
            ),
          ),
        );
      },
    );

    test(
      'when a Cookie header with an invalid value is passed then the server responds '
      'with a bad request including a message that states the cookie value is invalid',
      () async {
        expect(
          getServerRequestHeaders(
            server: server,
            touchHeaders: (final h) => h.cookie,
            headers: {'cookie': 'sessionId=abc123; userId=42\x7F'},
          ),
          throwsA(
            isA<BadRequestException>().having(
              (final e) => e.message,
              'message',
              contains('Invalid cookie value'),
            ),
          ),
        );
      },
    );

    test('when a Cookie header with an invalid value is passed '
        'then the server does not respond with a bad request if the headers '
        'is not actually used', () async {
      final headers = await getServerRequestHeaders(
        server: server,
        touchHeaders: (_) {},
        headers: {'cookie': 'sessionId=abc123; userId=42\x7F'},
      );

      expect(headers, isNotNull);
    });

    test(
      'when a valid Cookie header is passed with an empty name then it should parse the cookies correctly',
      () async {
        final headers = await getServerRequestHeaders(
          server: server,
          touchHeaders: (final h) => h.cookie,
          headers: {'cookie': '=abc123; userId=42'},
        );

        expect(
          headers.cookie?.cookies.map((final c) => c.name).toList(),
          equals(['', 'userId']),
        );
        expect(
          headers.cookie?.cookies.map((final c) => c.value).toList(),
          equals(['abc123', '42']),
        );
      },
    );

    test(
      'when a valid Cookie header is passed then it should parse the cookies correctly',
      () async {
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
      },
    );

    test(
      'when a Cookie header with encoded characters in the value is passed then it should parse correctly',
      () async {
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
          equals(['abc 123', '42']),
        );
      },
    );

    test(
      'when a valid Cookie header with duplicate cookies is passed then it should '
      'parse the cookies correctly and remove the duplicates',
      () async {
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
      },
    );

    test(
      'when a Cookie header is passed with extra whitespace then it should parse the cookies correctly',
      () async {
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
      },
    );
  });

  group('Given a Cookie header without validation', () {
    late RelicServer server;

    setUp(() async {
      server = await createServer();
    });

    tearDown(() => server.close());

    group('when parsing an invalid cookie header', () {
      test(
        'when an invalid Cookie header is passed then it should return null',
        () async {
          final headers = await getServerRequestHeaders(
            server: server,
            touchHeaders: (_) {},
            headers: {'cookie': 'sessionId=abc123; invalidCookie'},
          );

          expect(Headers.cookie[headers].valueOrNullIfInvalid, isNull);
          expect(() => headers.cookie, throwsInvalidHeader);
        },
      );
    });
  });
}
