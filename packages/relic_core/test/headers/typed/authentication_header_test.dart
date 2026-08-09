import 'package:relic_core/relic_core.dart';
import 'package:test/test.dart';

void main() {
  group('AuthenticationHeader.parse with adversarial input', () {
    group('Given a long value containing no auth-param separators,', () {
      test('when parsed, '
          'then it completes without super-linear backtracking.', () {
        final value = 'Digest ${'a' * 32000}';

        final stopwatch = Stopwatch()..start();
        expect(() => AuthenticationHeader.parse(value), returnsNormally);
        stopwatch.stop();

        expect(
          stopwatch.elapsedMilliseconds,
          lessThan(1000),
          reason: 'Parsing must be linear in the length of the value',
        );
      });
    });
  });

  group('AuthenticationHeader encoding', () {
    String encode(final AuthenticationHeader header) {
      final headers = Headers.build((final mh) => mh.wwwAuthenticate = header);
      return headers[Headers.wwwAuthenticateHeader]!.first;
    }

    group('Given a realm derived from request data', () {
      const attack = 'x", Basic realm="y';

      test('when the challenge is encoded, '
          'then the realm does not terminate early.', () {
        final encoded = encode(
          AuthenticationHeader(
            scheme: 'Basic',
            parameters: [AuthenticationParameter('realm', attack)],
          ),
        );

        final withoutEscapes = encoded
            .replaceAll(r'\\', '')
            .replaceAll(r'\"', '');

        expect(
          '"'.allMatches(withoutEscapes).length,
          2,
          reason:
              'The realm must be delimited by exactly one pair of quotes, so '
              'the interior quote has to be escaped. Encoded as: $encoded',
        );
      });
    });

    group('Given a scheme that is not a token', () {
      test('when the challenge is encoded, '
          'then it throws rather than emitting a broken scheme.', () {
        expect(
          () => encode(
            AuthenticationHeader(scheme: 'Bas ic', parameters: const []),
          ),
          throwsFormatException,
        );
      });
    });

    group('Given a parameter name that is not a token', () {
      test('when the challenge is encoded, '
          'then it throws.', () {
        expect(
          () => encode(
            AuthenticationHeader(
              scheme: 'Basic',
              parameters: [AuthenticationParameter('re alm', 'x')],
            ),
          ),
          throwsFormatException,
        );
      });
    });

    group('Given an ordinary challenge', () {
      test('when it is encoded and parsed back, '
          'then it round-trips unchanged.', () {
        final header = AuthenticationHeader(
          scheme: 'Digest',
          parameters: [
            AuthenticationParameter('realm', 'example zone'),
            AuthenticationParameter('qop', 'auth'),
          ],
        );

        final reparsed = AuthenticationHeader.parse(encode(header));

        expect(reparsed.scheme, 'Digest');
        expect(reparsed.parameters.map((final p) => p.key), ['realm', 'qop']);
        expect(reparsed.parameters.map((final p) => p.value), [
          'example zone',
          'auth',
        ]);
      });
    });

    group('Given a token68 challenge', () {
      test('when it is encoded and parsed back, '
          'then the opaque token round-trips as an unnamed parameter.', () {
        final header = AuthenticationHeader(
          scheme: 'Bearer',
          parameters: [AuthenticationParameter('', 'abc123')],
        );

        expect(encode(header), 'Bearer abc123');

        final reparsed = AuthenticationHeader.parse(encode(header));
        expect(reparsed.scheme, 'Bearer');
        expect(reparsed.parameters.single.key, isEmpty);
        expect(reparsed.parameters.single.value, 'abc123');
      });
    });

    group('Given a token68 challenge with base64 padding', () {
      test('when it is encoded and parsed back, '
          'then the padded token round-trips unchanged.', () {
        final header = AuthenticationHeader.parse('Negotiate YWJjZA==');

        expect(encode(header), 'Negotiate YWJjZA==');

        final reparsed = AuthenticationHeader.parse(encode(header));
        expect(reparsed.scheme, 'Negotiate');
        expect(reparsed.parameters.single.key, isEmpty);
        expect(reparsed.parameters.single.value, 'YWJjZA==');
      });
    });

    group('Given an unnamed parameter that is not a token68 value', () {
      test('when the challenge is encoded, '
          'then it throws rather than smuggling a second challenge.', () {
        expect(
          () => encode(
            AuthenticationHeader(
              scheme: 'Basic',
              parameters: [AuthenticationParameter('', 'x, Basic realm="y"')],
            ),
          ),
          throwsFormatException,
        );
      });
    });
  });

  group('AuthenticationHeader.parse', () {
    group('Given a challenge with quoted parameters,', () {
      test('when parsed, '
          'then the scheme and parameters are recovered.', () {
        final header = AuthenticationHeader.parse(
          'Digest realm="example", qop="auth"',
        );

        expect(header.scheme, equals('Digest'));
        expect(header.parameters.map((final p) => p.key), ['realm', 'qop']);
        expect(header.parameters.map((final p) => p.value), [
          'example',
          'auth',
        ]);
      });
    });

    group('Given a challenge with a bare token parameter value,', () {
      test('when parsed, '
          'then the unquoted value is recovered.', () {
        final header = AuthenticationHeader.parse('Digest algorithm=MD5');

        expect(header.scheme, equals('Digest'));
        expect(header.parameters.single.key, equals('algorithm'));
        expect(header.parameters.single.value, equals('MD5'));
      });
    });

    group('Given a scheme with a single opaque token, such as Bearer,', () {
      test('when parsed, '
          'then the token is kept as an unnamed parameter.', () {
        final header = AuthenticationHeader.parse('Bearer abc123');

        expect(header.scheme, equals('Bearer'));
        expect(header.parameters.single.key, isEmpty);
        expect(header.parameters.single.value, equals('abc123'));
      });
    });

    group('Given a parameter part of only list separators,', () {
      test(
        'when parsed, '
        'then it falls back to the token68 form instead of yielding no parameters.',
        () {
          final header = AuthenticationHeader.parse('Basic ,');

          expect(header.scheme, equals('Basic'));
          expect(header.parameters.single.key, isEmpty);
          expect(header.parameters.single.value, equals(','));
        },
      );
    });
  });
}
