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
  });
}
