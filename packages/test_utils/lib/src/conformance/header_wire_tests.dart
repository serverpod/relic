import 'dart:convert';
import 'dart:io' as io;

import 'package:relic_core/relic_core.dart';
import 'package:test/test.dart';

import 'conformance.dart';

/// How the bytes of a field line become the values a handler reads.
///
/// An HTTP client library normalizes or refuses most of these before they
/// reach the wire, so the tests write the requests to a socket as bytes.
void headerWireTests(AdapterConformance conformance) {
  group('Given a handler that reports the field values it received', () {
    late RelicServer server;
    late int handled;

    setUp(() async {
      handled = 0;
      server = await conformance.serve((req) {
        handled++;
        return Response.ok(
          body: Body.fromString(
            jsonEncode({
              'x-t': req.headers['x-t'],
              'cookie': req.headers['cookie'],
            }),
          ),
        );
      });
    });

    tearDown(() => server.close(force: true));

    /// Everything the server writes back for a GET with [fieldLines] in
    /// its head.
    Future<String> send(List<int> fieldLines) async {
      final socket = await io.Socket.connect(
        io.InternetAddress.loopbackIPv4,
        server.port,
      );
      socket.add(ascii.encode('GET / HTTP/1.1\r\nHost: localhost\r\n'));
      socket.add(fieldLines);
      socket.add(ascii.encode('Connection: close\r\n\r\n'));
      await socket.flush();
      final reply = await utf8
          .decodeStream(socket)
          .timeout(const Duration(seconds: 5));
      socket.destroy();
      return reply;
    }

    /// The field values the handler reported for [fieldLines].
    Future<Map<String, dynamic>> received(List<int> fieldLines) async {
      final reply = await send(fieldLines);
      expect(reply, startsWith('HTTP/1.1 200'));
      return jsonDecode(splitHead(reply).body) as Map<String, dynamic>;
    }

    /// A refused request never reaches the handler.
    ///
    /// The adapter answers 400 or hangs up without an answer.
    Future<void> expectRefused(List<int> fieldLines) async {
      final reply = await send(fieldLines);
      expect(reply, anyOf(isEmpty, startsWith('HTTP/1.1 400')));
      expect(handled, 0);
    }

    test('when a value has spaces and tabs around it, '
        'then the handler reads it without them', () async {
      final values = await received(ascii.encode('X-T:  \t abc \t \r\n'));

      expect(values['x-t'], ['abc']);
    });

    test('when no space follows the colon, '
        'then the handler reads the value', () async {
      final values = await received(ascii.encode('X-T:abc\r\n'));

      expect(values['x-t'], ['abc']);
    });

    test('when a value is empty, '
        'then the handler reads one empty value', () async {
      final values = await received(ascii.encode('X-T:\r\n'));

      expect(values['x-t'], ['']);
    });

    test('when a value is only whitespace, '
        'then the handler reads one empty value', () async {
      final values = await received(ascii.encode('X-T:   \t \r\n'));

      expect(values['x-t'], ['']);
    });

    test('when a field is sent on two lines, '
        'then the handler reads two values in order', () async {
      final values = await received(ascii.encode('X-T: a\r\nX-T: b\r\n'));

      expect(values['x-t'], ['a', 'b']);
    });

    test('when one line holds a comma separated list, '
        'then the handler reads it as one value', () async {
      final values = await received(ascii.encode('X-T: a, b ,c\r\n'));

      expect(values['x-t'], ['a, b ,c']);
    });

    test('when Cookie is sent on two lines, '
        'then the handler reads two values in order', () async {
      final values = await received(
        ascii.encode('Cookie: a=1\r\nCookie: b=2\r\n'),
      );

      expect(values['cookie'], ['a=1', 'b=2']);
    });

    test('when a field name is sent in mixed case, '
        'then the handler reads it by its lowercase name', () async {
      final values = await received(ascii.encode('x-T: abc\r\n'));

      expect(values['x-t'], ['abc']);
    });

    test('when a value holds a tab between two words, '
        'then the handler reads the tab', () async {
      final values = await received(ascii.encode('X-T: a\tb\r\n'));

      expect(values['x-t'], ['a\tb']);
    });

    test('when a value holds a byte above 127, '
        'then the handler reads it as the Latin-1 character', () async {
      final values = await received([
        ...ascii.encode('X-T: caf'),
        0xE9,
        ...ascii.encode('\r\n'),
      ]);

      expect(values['x-t'], ['caf\u00e9']);
    });

    test('when a value holds UTF-8 for one character, '
        'then the handler reads one Latin-1 character per byte', () async {
      final values = await received([
        ...ascii.encode('X-T: caf'),
        ...utf8.encode('\u00e9'),
        ...ascii.encode('\r\n'),
      ]);

      expect(values['x-t'], ['caf\u00c3\u00a9']);
    });

    test('when whitespace precedes the colon, '
        'then the request is refused', () async {
      await expectRefused(ascii.encode('X-T : abc\r\n'));
    });

    test('when a value holds a NUL byte, '
        'then the request is refused', () async {
      await expectRefused([
        ...ascii.encode('X-T: a'),
        0,
        ...ascii.encode('b\r\n'),
      ]);
    });

    test('when a value holds a CR that no LF follows, '
        'then the request is refused', () async {
      await expectRefused(ascii.encode('X-T: a\rb\r\n'));
    });

    test(
      'when a value continues on a folded line, '
      'then the request is refused or the handler reads the two parts joined by one space',
      () async {
        // RFC 9112 5.2 allows a server either answer to an obsolete fold.
        final reply = await send(ascii.encode('X-T: a\r\n b\r\n'));

        if (handled == 0) {
          expect(reply, anyOf(isEmpty, startsWith('HTTP/1.1 400')));
        } else {
          expect(reply, startsWith('HTTP/1.1 200'));
          expect(
            reply,
            endsWith(
              jsonEncode({
                'x-t': ['a b'],
                'cookie': null,
              }),
            ),
          );
        }
      },
    );
  });
}
