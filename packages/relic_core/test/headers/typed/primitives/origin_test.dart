import 'package:relic_core/src/headers/typed/primitives/host.dart';
import 'package:relic_core/src/headers/typed/primitives/origin.dart';
import 'package:test/test.dart';

void main() {
  group('Origin.parse', () {
    group('Given the literal string "null",', () {
      test('when parsed, '
          'then the OpaqueOrigin sentinel is returned.', () {
        expect(Origin.parse('null'), same(OpaqueOrigin.instance));
      });
    });

    group('Given a scheme://host origin,', () {
      test('when parsed, '
          'then a TupleOrigin with normalized scheme is returned.', () {
        final o = Origin.parse('https://example.com') as TupleOrigin;

        expect(o.scheme, equals('https'));
        expect(o.host.host, equals('example.com'));
        expect(o.host.port, isNull);
      });

      test('when the scheme has mixed case, '
          'then it is lowercased.', () {
        final o = Origin.parse('HTTPS://example.com') as TupleOrigin;

        expect(o.scheme, equals('https'));
      });
    });

    group('Given a scheme://host:port origin,', () {
      test('when parsed, '
          'then the port is preserved.', () {
        final o = Origin.parse('http://example.com:8080') as TupleOrigin;

        expect(o.host.port, equals(8080));
      });
    });

    group('Given a scheme://[ipv6]:port origin,', () {
      test('when parsed, '
          'then the IPv6 host is unbracketed and port preserved.', () {
        final o = Origin.parse('http://[::1]:8080') as TupleOrigin;

        expect(o.host.host, equals('::1'));
        expect(o.host.port, equals(8080));
      });
    });

    group('Given an origin with a trailing slash,', () {
      test('when parsed, '
          'then it throws a FormatException.', () {
        expect(
          () => Origin.parse('https://example.com/'),
          throwsFormatException,
        );
      });
    });

    group('Given an origin with a path,', () {
      test('when parsed, '
          'then it throws a FormatException.', () {
        expect(
          () => Origin.parse('https://example.com/path'),
          throwsFormatException,
        );
      });
    });

    group('Given an origin with a query or fragment,', () {
      test('when parsed, '
          'then it throws a FormatException.', () {
        expect(
          () => Origin.parse('https://example.com?q=1'),
          throwsFormatException,
        );
        expect(
          () => Origin.parse('https://example.com#frag'),
          throwsFormatException,
        );
      });
    });

    group('Given an input missing "://" between scheme and host,', () {
      test('when parsed, '
          'then it throws a FormatException.', () {
        expect(() => Origin.parse('https:example.com'), throwsFormatException);
        expect(() => Origin.parse('example.com'), throwsFormatException);
      });
    });

    group('Given an empty host after "://",', () {
      test('when parsed, '
          'then it throws a FormatException.', () {
        expect(() => Origin.parse('https://'), throwsFormatException);
      });
    });
  });

  group('TupleOrigin construction', () {
    group('Given an invalid scheme,', () {
      test('when constructed, '
          'then it throws a FormatException.', () {
        expect(
          () => TupleOrigin(scheme: '', host: Host('example.com')),
          throwsFormatException,
        );
        expect(
          () => TupleOrigin(scheme: '1http', host: Host('example.com')),
          throwsFormatException,
        );
        expect(
          () => TupleOrigin(scheme: 'ht tp', host: Host('example.com')),
          throwsFormatException,
        );
      });
    });

    group('Given a valid scheme,', () {
      test('when constructed, '
          'then the scheme is stored in lowercase.', () {
        final o = TupleOrigin(scheme: 'HTTPS', host: Host('example.com'));

        expect(o.scheme, equals('https'));
      });

      test('when constructed with allowed RFC 3986 specials, '
          'then it is accepted.', () {
        final o = TupleOrigin(scheme: 'a+b-c.d', host: Host('example.com'));

        expect(o.scheme, equals('a+b-c.d'));
      });
    });
  });

  group('Origin.encode', () {
    group('Given an OpaqueOrigin,', () {
      test('when encoded, '
          'then the wire value is "null".', () {
        expect(OpaqueOrigin.instance.encode(), equals('null'));
      });
    });

    group('Given a TupleOrigin without port,', () {
      test('when encoded, '
          'then no port suffix appears.', () {
        final o = TupleOrigin(scheme: 'https', host: Host('example.com'));

        expect(o.encode(), equals('https://example.com'));
      });
    });

    group('Given a TupleOrigin with port,', () {
      test('when encoded, '
          'then the port suffix is included.', () {
        final o = TupleOrigin(scheme: 'http', host: Host('example.com', 8080));

        expect(o.encode(), equals('http://example.com:8080'));
      });
    });

    group('Given a TupleOrigin with an IPv6 host,', () {
      test('when encoded, '
          'then the host appears bracketed.', () {
        final o = TupleOrigin(scheme: 'http', host: Host('::1', 8080));

        expect(o.encode(), equals('http://[::1]:8080'));
      });
    });

    group('Given an Origin round-tripped through parse,', () {
      test('when re-encoded, '
          'then the wire form matches the input.', () {
        for (final input in const [
          'null',
          'https://example.com',
          'http://example.com:8080',
          'http://[::1]',
          'http://[::1]:8080',
          'https://[2001:db8::1]:443',
        ]) {
          expect(Origin.parse(input).encode(), equals(input));
        }
      });
    });
  });

  group('Origin equality', () {
    group('Given the OpaqueOrigin sentinel,', () {
      test('when used as Set elements, '
          'then duplicates collapse to one.', () {
        final a = TupleOrigin(scheme: 'https', host: Host('example.com'));
        final b = TupleOrigin(scheme: 'HTTPS', host: Host('Example.com'));
        final s = <Origin>{a, b};

        expect(s, hasLength(1));
      });

      test('when compared with itself, '
          'then it is equal and shares its hashCode.', () {
        expect(OpaqueOrigin.instance, equals(OpaqueOrigin.instance));
        expect(
          OpaqueOrigin.instance.hashCode,
          equals(OpaqueOrigin.instance.hashCode),
        );
      });
    });

    group('Given two TupleOrigins with same parts,', () {
      test('when compared, '
          'then they are equal.', () {
        final a = TupleOrigin(scheme: 'https', host: Host('example.com'));
        final b = TupleOrigin(scheme: 'HTTPS', host: Host('Example.com'));

        expect(a, equals(b));
        expect(a.hashCode, equals(b.hashCode));
      });
    });

    group('Given a TupleOrigin and an OpaqueOrigin,', () {
      test('when compared, '
          'then they are not equal.', () {
        final t = TupleOrigin(scheme: 'https', host: Host('example.com'));

        expect(t == OpaqueOrigin.instance, isFalse);
        expect(OpaqueOrigin.instance == t, isFalse);
      });
    });
  });
}
