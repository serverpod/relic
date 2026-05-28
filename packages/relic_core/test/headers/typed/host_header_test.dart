import 'package:relic_core/relic_core.dart';
import 'package:test/test.dart';

void main() {
  group('HostHeader.fromUri default-port handling', () {
    group('Given a URI with an explicit port,', () {
      test('when HostHeader.fromUri is called, '
          'then the port is preserved.', () {
        final h = HostHeader.fromUri(Uri.parse('http://example.com:8080/'));

        expect(h.host, equals('example.com'));
        expect(h.port, equals(8080));
      });
    });

    group('Given an http URI with the default (implicit) port,', () {
      test('when HostHeader.fromUri is called, '
          'then port is null (no coercion to 80).', () {
        final h = HostHeader.fromUri(Uri.parse('http://example.com/'));

        expect(h.port, isNull);
      });
    });

    group('Given an https URI with the default (implicit) port,', () {
      test('when HostHeader.fromUri is called, '
          'then port is null (no coercion to 443).', () {
        final h = HostHeader.fromUri(Uri.parse('https://example.com/'));

        expect(h.port, isNull);
      });
    });

    group('Given an HTTP URI with no port and no path,', () {
      test('when HostHeader.fromUri is called, '
          'then port is null.', () {
        final h = HostHeader.fromUri(Uri.parse('http://example.com'));

        expect(h.port, isNull);
      });
    });

    group('Given an IPv6 URI,', () {
      test('when HostHeader.fromUri is called, '
          'then the host keeps its brackets and encodes unambiguously.', () {
        final h = HostHeader.fromUri(Uri.parse('http://[::1]:8080/'));

        expect(h.host, equals('[::1]'));
        expect(h.port, equals(8080));
      });

      test('when compared with the equivalent parse(), '
          'then the two are equal.', () {
        final fromUri = HostHeader.fromUri(Uri.parse('http://[::1]:8080/'));
        final parsed = HostHeader.parse('[::1]:8080');

        expect(fromUri, equals(parsed));
      });
    });
  });
}
