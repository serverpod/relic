import 'package:relic_core/relic_core.dart';
import 'package:test/test.dart';

void main() {
  group('SetCookie Domain attribute (regression for #355)', () {
    group('Given a SetCookie with a Host domain,', () {
      test('when encoded via codec, '
          'then Domain= carries only the hostname (no scheme or slashes).', () {
        final cookie = SetCookie(
          name: 'sid',
          value: 'abc',
          domain: Host('abc.co'),
        );

        expect(cookie.encode(), equals('sid=abc; Domain=abc.co'));
      });

      test('when constructed with an IPv6 host, '
          'then Domain= encodes it bracketed.', () {
        final cookie = SetCookie(
          name: 'sid',
          value: 'abc',
          domain: Host('::1'),
        );

        expect(cookie.encode(), contains('Domain=[::1]'));
      });
    });

    group('Given a Set-Cookie wire value with a Domain attribute,', () {
      test('when parsed and re-encoded, '
          'then the Domain hostname round-trips.', () {
        final parsed = SetCookie.parse(
          'sid=abc; Domain=example.com; Path=/api',
        );

        expect(parsed.domain?.host, equals('example.com'));
        expect(parsed.path, equals('/api'));
        expect(parsed.encode(), contains('Domain=example.com'));
      });
    });

    group('Given a Host domain that carries a port,', () {
      test('when used to construct a SetCookie, '
          'then it throws (RFC 6265 5.2.3 forbids a port in Domain).', () {
        expect(
          () => SetCookie(
            name: 'sid',
            value: 'abc',
            domain: Host('example.com', 8080),
          ),
          throwsFormatException,
        );
      });
    });

    group('Given a Domain with a leading dot,', () {
      test('when constructed, '
          'then the dot is stripped (RFC 6265 5.2.3 normalization).', () {
        final header = SetCookie(
          name: 'sid',
          value: 'abc',
          domain: Host('.example.com'),
        );

        expect(header.domain?.host, equals('example.com'));
        expect(header.encode(), contains('Domain=example.com'));
      });

      test('when parsed from the wire, '
          'then the dot is stripped.', () {
        final parsed = SetCookie.parse('sid=abc; Domain=.example.com');

        expect(parsed.domain?.host, equals('example.com'));
      });
    });

    group('Given a Domain with several leading dots,', () {
      test('when constructed, '
          'then the whole leading run is stripped (not just one).', () {
        final cookie = SetCookie(
          name: 'sid',
          value: 'abc',
          domain: Host('..example.com'),
        );

        expect(cookie.domain?.host, equals('example.com'));
        expect(cookie.encode(), contains('Domain=example.com'));
      });
    });

    group('Given a Domain that is only dots,', () {
      test('when constructed, '
          'then it throws rather than emitting an empty Host.', () {
        expect(
          () => SetCookie(name: 'sid', value: 'abc', domain: Host('.')),
          throwsFormatException,
        );
      });
    });
  });

  group('SetCookie parser hardening', () {
    group('Given a cookie name that contains an attribute keyword,', () {
      test('when parsed, '
          'then the first pair is the cookie, not the attribute.', () {
        final parsed = SetCookie.parse('sessionhttponly=xyz');

        expect(parsed.name, equals('sessionhttponly'));
        expect(parsed.value, equals('xyz'));
        expect(parsed.httpOnly, isFalse);
      });
    });

    group('Given a cookie value that contains an "=",', () {
      test('when parsed, '
          'then only the first "=" splits name from value.', () {
        final parsed = SetCookie.parse('token=a=b=c');

        expect(parsed.name, equals('token'));
        expect(parsed.value, equals('a=b=c'));
      });
    });

    group('Given a Path attribute value that contains an "=",', () {
      test('when parsed, '
          'then the full path after the first "=" is preserved.', () {
        final parsed = SetCookie.parse('sid=x; Path=/foo=bar');

        expect(parsed.path, equals('/foo=bar'));
      });
    });

    group('Given a cookie name equal to an attribute label,', () {
      test('when encoded, '
          'then the cookie-pair is not collapsed with the attribute.', () {
        final cookie = SetCookie(name: 'Path', value: '/foo', path: '/x');

        final encoded = cookie.encode();
        expect(encoded, contains('Path=/foo'));
        expect(encoded, contains('Path=/x'));
        expect(encoded, equals('Path=/foo; Path=/x'));
      });
    });

    group('Given a path containing a control character,', () {
      test('when used to construct a SetCookie, '
          'then it throws to prevent header injection.', () {
        expect(
          () => SetCookie(
            name: 'sid',
            value: 'x',
            path: '/foo\r\nSet-Cookie: evil=1',
          ),
          throwsFormatException,
        );
      });
    });

    group('Given an empty cookie name (the "=value" quirk),', () {
      test('when encoded, '
          'then the cookie-pair is still emitted and round-trips.', () {
        final cookie = SetCookie(name: '', value: 'abc123', secure: true);

        final encoded = cookie.encode();
        expect(encoded, equals('=abc123; Secure'));

        final reparsed = SetCookie.parse(encoded);
        expect(reparsed.name, isEmpty);
        expect(reparsed.value, equals('abc123'));
        expect(reparsed.secure, isTrue);
      });
    });
  });

  group('SetCookieHeader collection', () {
    final a = SetCookie(name: 'a', value: '1');
    final b = SetCookie(name: 'b', value: '2', secure: true);

    group('Given several Set-Cookie lines,', () {
      test('when decoded, '
          'then each line is one cookie, in order.', () {
        final header = SetCookieHeader.codec.decode(['a=1', 'b=2; Secure']);

        expect(header.cookies.map((final c) => c.name), equals(['a', 'b']));
        expect(header.cookies[1].secure, isTrue);
      });

      test('when encoded, '
          'then each cookie is its own Set-Cookie line.', () {
        expect(
          SetCookieHeader.codec.encode(SetCookieHeader([a, b])),
          equals(['a=1', 'b=2; Secure']),
        );
      });
    });

    group('Given an existing collection,', () {
      test('when add is called, '
          'then a new collection with the cookie appended is returned.', () {
        final header = const SetCookieHeader.empty().add(a).add(b);

        expect(header.cookies, equals([a, b]));
      });

      test('when addAll is called, '
          'then all cookies are appended in order.', () {
        expect(SetCookieHeader([a]).addAll([b]).cookies, equals([a, b]));
      });
    });

    group('Given a malformed Set-Cookie line,', () {
      test('when decoded, '
          'then it throws (strict decode)', () {
        // Set-Cookie is server-produced, so there is no need to be lenient
        expect(
          () => SetCookieHeader.codec.decode(['a=1', 'no-equals', 'b=2']),
          throwsFormatException,
        );
      });
    });
  });
}
