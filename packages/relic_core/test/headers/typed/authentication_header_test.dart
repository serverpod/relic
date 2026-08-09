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
