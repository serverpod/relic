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
  });
}
