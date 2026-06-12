import 'package:relic_core/relic_core.dart';
import 'package:test/test.dart';

void main() {
  group('DigestAuthorizationHeader encoding', () {
    group('Given a Digest header,', () {
      test('when encoded, '
          'then the scheme and first param are separated by a space.', () {
        final header = DigestAuthorizationHeader(
          username: 'user',
          realm: 'realm',
          nonce: 'nonce',
          uri: '/',
          response: 'resp',
        );

        expect(header.headerValue, startsWith('Digest username='));
        expect(header.headerValue, isNot(contains('Digest, ')));
      });

      test('when algorithm/qop/nc are present, '
          'then they are emitted as bare tokens (not quoted).', () {
        final header = DigestAuthorizationHeader(
          username: 'user',
          realm: 'realm',
          nonce: 'nonce',
          uri: '/',
          response: 'resp',
          algorithm: 'MD5',
          qop: 'auth',
          nc: '00000001',
        );

        expect(header.headerValue, contains('algorithm=MD5'));
        expect(header.headerValue, contains('qop=auth'));
        expect(header.headerValue, contains('nc=00000001'));
        expect(header.headerValue, isNot(contains('algorithm="MD5"')));
      });
    });

    group('Given a Digest header with a quote in a quoted field,', () {
      test('when encoded, '
          'then the interior quote is escaped as a quoted-pair.', () {
        final header = DigestAuthorizationHeader(
          username: 'a"b',
          realm: 'realm',
          nonce: 'nonce',
          uri: '/',
          response: 'resp',
        );

        expect(header.headerValue, contains(r'username="a\"b"'));
      });
    });

    group(
      'Given a Digest header with a control character in a quoted field,',
      () {
        test('when encoded, '
            'then it throws to prevent header injection.', () {
          final header = DigestAuthorizationHeader(
            username: 'user\r\nInjected: evil',
            realm: 'realm',
            nonce: 'nonce',
            uri: '/',
            response: 'resp',
          );

          expect(() => header.headerValue, throwsFormatException);
        });
      },
    );
  });

  group('DigestAuthorizationHeader round-trip', () {
    group('Given a header with bare-token algorithm/qop/nc,', () {
      test('when encoded and re-parsed, '
          'then all fields are preserved.', () {
        final header = DigestAuthorizationHeader(
          username: 'user',
          realm: 'realm',
          nonce: 'nonce',
          uri: '/',
          response: 'resp',
          algorithm: 'MD5',
          qop: 'auth',
          nc: '00000001',
          cnonce: 'cnonce',
          opaque: 'opaque',
        );

        final reparsed = DigestAuthorizationHeader.parse(
          header.headerValue.substring('Digest '.length),
        );

        expect(reparsed.username, equals('user'));
        expect(reparsed.algorithm, equals('MD5'));
        expect(reparsed.qop, equals('auth'));
        expect(reparsed.nc, equals('00000001'));
        expect(reparsed.cnonce, equals('cnonce'));
        expect(reparsed.opaque, equals('opaque'));
      });
    });

    group('Given a username containing an escaped quote,', () {
      test('when encoded and re-parsed, '
          'then the original username is recovered.', () {
        final header = DigestAuthorizationHeader(
          username: r'a"b',
          realm: 'realm',
          nonce: 'nonce',
          uri: '/',
          response: 'resp',
        );

        final reparsed = DigestAuthorizationHeader.parse(
          header.headerValue.substring('Digest '.length),
        );

        expect(reparsed.username, equals(r'a"b'));
      });
    });
  });

  group('DigestAuthorizationHeader.parse with bare tokens', () {
    group('Given a wire value with unquoted algorithm/qop/nc,', () {
      test('when parsed, '
          'then the token-form parameters are captured.', () {
        final header = DigestAuthorizationHeader.parse(
          'username="user", realm="realm", nonce="n", uri="/", '
          'response="r", algorithm=MD5, qop=auth, nc=00000001',
        );

        expect(header.algorithm, equals('MD5'));
        expect(header.qop, equals('auth'));
        expect(header.nc, equals('00000001'));
      });
    });

    group('Given a bare auth-param value that is not a token,', () {
      test('when parsed, '
          'then it throws a FormatException.', () {
        expect(
          () => DigestAuthorizationHeader.parse(
            'username="user", realm="r", nonce="n", uri="/", '
            'response="r", algorithm=MD5;evil',
          ),
          throwsFormatException,
        );
      });
    });
  });

  group('DigestAuthorizationHeader construction', () {
    group('Given a non-token algorithm/qop,', () {
      test('when constructed, '
          'then it throws (these are emitted unquoted).', () {
        expect(
          () => DigestAuthorizationHeader(
            username: 'u',
            realm: 'r',
            nonce: 'n',
            uri: '/',
            response: 'r',
            algorithm: 'MD5\r\nInjected: 1',
          ),
          throwsFormatException,
        );
      });
    });

    group('Given an nc that is not exactly 8 hex digits,', () {
      test('when constructed, '
          'then it throws (RFC 7616 nc-value = 8LHEX).', () {
        for (final bad in ['123', '0000000g', '000000010']) {
          expect(
            () => DigestAuthorizationHeader(
              username: 'u',
              realm: 'r',
              nonce: 'n',
              uri: '/',
              response: 'r',
              nc: bad,
            ),
            throwsFormatException,
            reason: 'nc="$bad" should be rejected',
          );
        }
      });
    });
  });

  group('AuthorizationHeader scheme dispatch', () {
    group('Given a scheme in lowercase,', () {
      test('when parsed, '
          'then it is matched case-insensitively.', () {
        expect(
          AuthorizationHeader.parse('bearer abc123'),
          isA<BearerAuthorizationHeader>(),
        );
        expect(
          AuthorizationHeader.parse(
            'DIGEST username="u", realm="r", '
            'nonce="n", uri="/", response="r"',
          ),
          isA<DigestAuthorizationHeader>(),
        );
      });
    });
  });

  group('BasicAuthorizationHeader empty password', () {
    group('Given an empty password (apikey pattern),', () {
      test('when constructed and round-tripped, '
          'then the empty password is preserved.', () {
        final header = BasicAuthorizationHeader(
          username: 'apikey',
          password: '',
        );

        expect(header.password, isEmpty);

        final reparsed =
            AuthorizationHeader.parse(header.headerValue)
                as BasicAuthorizationHeader;
        expect(reparsed.username, equals('apikey'));
        expect(reparsed.password, isEmpty);
      });
    });
  });
}
