import 'package:relic_core/src/headers/typed/primitives/host.dart';
import 'package:test/test.dart';

void main() {
  group('Host construction', () {
    group('Given a non-empty host string,', () {
      test('when Host is constructed with no port, '
          'then port is null and host is preserved.', () {
        final h = Host('example.com');

        expect(h.host, equals('example.com'));
        expect(h.port, isNull);
      });

      test('when Host is constructed with a port, '
          'then both fields are preserved.', () {
        final h = Host('example.com', 8080);

        expect(h.host, equals('example.com'));
        expect(h.port, equals(8080));
      });
    });

    group('Given an empty host string,', () {
      test('when Host is constructed, '
          'then it throws a FormatException.', () {
        expect(() => Host(''), throwsFormatException);
      });
    });

    group('Given a host string containing URI brackets,', () {
      test('when Host is constructed, '
          'then it throws a FormatException.', () {
        expect(() => Host('[::1]'), throwsFormatException);
        expect(() => Host('abc[def'), throwsFormatException);
      });
    });

    group('Given a port outside 0-65535,', () {
      test('when Host is constructed, '
          'then it throws a FormatException.', () {
        expect(() => Host('example.com', -1), throwsFormatException);
        expect(() => Host('example.com', 65536), throwsFormatException);
      });
    });
  });

  group('Host.fromUri', () {
    group('Given a URI with an explicit port,', () {
      test('when Host.fromUri is called, '
          'then the port is preserved.', () {
        final h = Host.fromUri(Uri.parse('http://example.com:8080/path'));

        expect(h.host, equals('example.com'));
        expect(h.port, equals(8080));
      });
    });

    group('Given a URI with a default port (no explicit port),', () {
      test('when Host.fromUri is called, '
          'then port is null rather than 80/443.', () {
        final h1 = Host.fromUri(Uri.parse('http://example.com/'));
        final h2 = Host.fromUri(Uri.parse('https://example.com/'));

        expect(h1.port, isNull);
        expect(h2.port, isNull);
      });
    });

    group('Given a URI with an IPv6 host,', () {
      test('when Host.fromUri is called, '
          'then host is stored unbracketed.', () {
        final h = Host.fromUri(Uri.parse('http://[::1]:8080/'));

        expect(h.host, equals('::1'));
        expect(h.port, equals(8080));
      });
    });

    group('Given a URI with no host,', () {
      test('when Host.fromUri is called, '
          'then it throws a FormatException.', () {
        expect(
          () => Host.fromUri(Uri.parse('/relative/path')),
          throwsFormatException,
        );
      });
    });
  });

  group('Host.parse', () {
    group('Given a bare reg-name,', () {
      test('when parsed, '
          'then host is the input and port is null.', () {
        final h = Host.parse('example.com');

        expect(h.host, equals('example.com'));
        expect(h.port, isNull);
      });
    });

    group('Given a reg-name with port,', () {
      test('when parsed, '
          'then host and port are split correctly.', () {
        final h = Host.parse('example.com:8080');

        expect(h.host, equals('example.com'));
        expect(h.port, equals(8080));
      });
    });

    group('Given an IPv4 with port,', () {
      test('when parsed, '
          'then host and port are split correctly.', () {
        final h = Host.parse('192.0.2.1:80');

        expect(h.host, equals('192.0.2.1'));
        expect(h.port, equals(80));
      });
    });

    group('Given a bracketed IPv6 with port,', () {
      test('when parsed, '
          'then host is unbracketed and port is preserved.', () {
        final h = Host.parse('[::1]:8080');

        expect(h.host, equals('::1'));
        expect(h.port, equals(8080));
      });
    });

    group('Given a bracketed IPv6 with no port,', () {
      test('when parsed, '
          'then host is unbracketed and port is null.', () {
        final h = Host.parse('[2001:db8::1]');

        expect(h.host, equals('2001:db8::1'));
        expect(h.port, isNull);
      });
    });

    group('Given an unbracketed IPv6 literal,', () {
      test('when parsed, '
          'then it throws a FormatException.', () {
        expect(() => Host.parse('::1:80'), throwsFormatException);
        expect(() => Host.parse('2001:db8::1'), throwsFormatException);
      });
    });

    group('Given an unterminated IP-literal,', () {
      test('when parsed, '
          'then it throws a FormatException.', () {
        expect(() => Host.parse('[::1'), throwsFormatException);
      });
    });

    group('Given an IP-literal followed by garbage,', () {
      test('when parsed, '
          'then it throws a FormatException.', () {
        expect(() => Host.parse('[::1]foo'), throwsFormatException);
      });
    });

    group('Given a port that is non-numeric,', () {
      test('when parsed, '
          'then it throws a FormatException.', () {
        expect(() => Host.parse('example.com:abc'), throwsFormatException);
      });
    });

    group('Given a port that exceeds 65535,', () {
      test('when parsed, '
          'then it throws a FormatException.', () {
        expect(() => Host.parse('example.com:65536'), throwsFormatException);
        expect(() => Host.parse('example.com:999999'), throwsFormatException);
      });
    });

    group('Given an empty port after colon,', () {
      test('when parsed, '
          'then it throws a FormatException.', () {
        expect(() => Host.parse('example.com:'), throwsFormatException);
      });
    });
  });

  group('Host.encode', () {
    group('Given a reg-name,', () {
      test('when encoded, '
          'then the wire form has no brackets.', () {
        expect(Host('example.com').encode(), equals('example.com'));
        expect(Host('example.com', 8080).encode(), equals('example.com:8080'));
      });
    });

    group('Given an IPv6 host,', () {
      test('when encoded, '
          'then the wire form is bracketed.', () {
        expect(Host('::1').encode(), equals('[::1]'));
        expect(Host('::1', 8080).encode(), equals('[::1]:8080'));
        expect(Host('2001:db8::1', 443).encode(), equals('[2001:db8::1]:443'));
      });
    });

    group('Given a Host round-tripped through parse,', () {
      test('when re-encoded, '
          'then the wire form matches the input.', () {
        for (final input in const [
          'example.com',
          'example.com:8080',
          '192.0.2.1',
          '192.0.2.1:80',
          '[::1]',
          '[::1]:8080',
          '[2001:db8::1]:443',
        ]) {
          expect(Host.parse(input).encode(), equals(input));
        }
      });
    });
  });

  group('Host equality and hashing', () {
    group('Given two Hosts that differ only in ASCII letter case,', () {
      test('when compared with ==, '
          'then they are equal.', () {
        expect(Host('Example.com') == Host('example.COM'), isTrue);
      });

      test('when their hashCodes are compared, '
          'then they are equal.', () {
        expect(
          Host('Example.com').hashCode,
          equals(Host('example.COM').hashCode),
        );
      });
    });

    group('Given two Hosts that differ only in port,', () {
      test('when compared with ==, '
          'then they are not equal.', () {
        expect(Host('example.com') == Host('example.com', 80), isFalse);
        expect(Host('example.com', 80) == Host('example.com', 443), isFalse);
      });
    });
  });
}
