import 'package:relic_core/relic_core.dart';
import 'package:test/test.dart';

void main() {
  group('SetCookieHeader Domain attribute (regression for #355)', () {
    group('Given a SetCookieHeader with a Host domain,', () {
      test('when encoded via codec, '
          'then Domain= carries only the hostname (no scheme or slashes).', () {
        final cookie = SetCookieHeader(
          name: 'sid',
          value: 'abc',
          domain: Host('abc.co'),
        );

        expect(
          SetCookieHeader.codec.encode(cookie).single,
          equals('sid=abc; Domain=abc.co'),
        );
      });

      test('when constructed with an IPv6 host, '
          'then Domain= encodes it bracketed.', () {
        final cookie = SetCookieHeader(
          name: 'sid',
          value: 'abc',
          domain: Host('::1'),
        );

        expect(
          SetCookieHeader.codec.encode(cookie).single,
          contains('Domain=[::1]'),
        );
      });
    });

    group('Given a Set-Cookie wire value with a Domain attribute,', () {
      test('when parsed and re-encoded, '
          'then the Domain hostname round-trips.', () {
        final parsed = SetCookieHeader.parse(
          'sid=abc; Domain=example.com; Path=/api',
        );

        expect(parsed.domain?.host, equals('example.com'));
        expect(parsed.path, equals('/api'));
        expect(
          SetCookieHeader.codec.encode(parsed).single,
          contains('Domain=example.com'),
        );
      });
    });

    group('Given a Host domain that carries a port,', () {
      test('when used to construct a SetCookieHeader, '
          'then it throws (RFC 6265 5.2.3 forbids a port in Domain).', () {
        expect(
          () => SetCookieHeader(
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
        final header = SetCookieHeader(
          name: 'sid',
          value: 'abc',
          domain: Host('.example.com'),
        );

        expect(header.domain?.host, equals('example.com'));
        expect(
          SetCookieHeader.codec.encode(header).single,
          contains('Domain=example.com'),
        );
      });

      test('when parsed from the wire, '
          'then the dot is stripped.', () {
        final parsed = SetCookieHeader.parse('sid=abc; Domain=.example.com');

        expect(parsed.domain?.host, equals('example.com'));
      });
    });
  });

  group('SetCookieHeader parser hardening', () {
    group('Given a cookie name that contains an attribute keyword,', () {
      test('when parsed, '
          'then the first pair is the cookie, not the attribute.', () {
        final parsed = SetCookieHeader.parse('sessionhttponly=xyz');

        expect(parsed.name, equals('sessionhttponly'));
        expect(parsed.value, equals('xyz'));
        expect(parsed.httpOnly, isFalse);
      });
    });

    group('Given a cookie value that contains an "=",', () {
      test('when parsed, '
          'then only the first "=" splits name from value.', () {
        final parsed = SetCookieHeader.parse('token=a=b=c');

        expect(parsed.name, equals('token'));
        expect(parsed.value, equals('a=b=c'));
      });
    });

    group('Given a Path attribute value that contains an "=",', () {
      test('when parsed, '
          'then the full path after the first "=" is preserved.', () {
        final parsed = SetCookieHeader.parse('sid=x; Path=/foo=bar');

        expect(parsed.path, equals('/foo=bar'));
      });
    });

    group('Given a cookie name equal to an attribute label,', () {
      test('when encoded, '
          'then the cookie-pair is not collapsed with the attribute.', () {
        final cookie = SetCookieHeader(name: 'Path', value: '/foo', path: '/x');

        final encoded = SetCookieHeader.codec.encode(cookie).single;
        expect(encoded, contains('Path=/foo'));
        expect(encoded, contains('Path=/x'));
        expect(encoded, equals('Path=/foo; Path=/x'));
      });
    });

    group('Given a path containing a control character,', () {
      test('when used to construct a SetCookieHeader, '
          'then it throws to prevent header injection.', () {
        expect(
          () => SetCookieHeader(
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
        final cookie = SetCookieHeader(name: '', value: 'abc123', secure: true);

        final encoded = SetCookieHeader.codec.encode(cookie).single;
        expect(encoded, equals('=abc123; Secure'));

        final reparsed = SetCookieHeader.parse(encoded);
        expect(reparsed.name, isEmpty);
        expect(reparsed.value, equals('abc123'));
        expect(reparsed.secure, isTrue);
      });
    });
  });
}
