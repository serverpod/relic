import 'package:relic/relic.dart';
import 'package:test/test.dart';
import 'package:relic/src/headers/standard_headers_extensions.dart';

import '../headers_test_utils.dart';
import '../docs/strict_validation_docs.dart';

/// Reference: https://developer.mozilla.org/en-US/docs/Web/HTTP/Headers/WWW-Authenticate
/// About empty value test, check the [StrictValidationDocs] class for more details.
void main() {
  group('Given a WWW-Authenticate header with the strict flag true',
      skip: 'drop strict mode', () {
    late RelicServer server;

    setUp(() async {
      server = await createServer(strictHeaders: true);
    });

    tearDown(() => server.close());

    test(
      'when an empty WWW-Authenticate header is passed then it should throw FormatException',
      () async {
        expect(
          () async => await getServerRequestHeaders(
            server: server,
            headers: {'www-authenticate': ''},
          ),
          throwsA(isA<BadRequestException>().having(
            (e) => e.message,
            'message',
            contains('Value cannot be empty'),
          )),
        );
      },
    );

    test(
      'when a WWW-Authenticate header with an invalid value is passed '
      'then the server does not respond with a bad request if the headers '
      'is not actually used',
      () async {
        var headers = await getServerRequestHeaders(
          server: server,
          headers: {'www-authenticate': 'Test'},
          eagerParseHeaders: false,
        );

        expect(headers, isNotNull);
      },
    );

    group('when Basic authentication', () {
      test('with realm parameter should parse scheme correctly', () async {
        var headers = await getServerRequestHeaders(
          server: server,
          headers: {'www-authenticate': 'Basic realm="Protected Area"'},
        );

        expect(headers.wwwAuthenticate?.scheme, equals('Basic'));
      });

      test('with realm parameter should parse realm correctly', () async {
        var headers = await getServerRequestHeaders(
          server: server,
          headers: {'www-authenticate': 'Basic realm="Protected Area"'},
        );

        expect(
          headers.wwwAuthenticate?.parameters
              .firstWhere((p) => p.key == 'realm')
              .value,
          equals('Protected Area'),
        );
      });
    });

    group('when Digest authentication', () {
      test('should parse scheme correctly', () async {
        var headers = await getServerRequestHeaders(
          server: server,
          headers: {
            'www-authenticate':
                'Digest realm="Protected Area", qop="auth", nonce="dcd98b7102dd2f0e8b11d0f600bfb0c093", opaque="5ccc069c403ebaf9f0171e9517f40e41"'
          },
        );

        expect(headers.wwwAuthenticate?.scheme, equals('Digest'));
      });

      test('should parse realm parameter correctly', () async {
        var headers = await getServerRequestHeaders(
          server: server,
          headers: {
            'www-authenticate':
                'Digest realm="Protected Area", qop="auth", nonce="dcd98b7102dd2f0e8b11d0f600bfb0c093", opaque="5ccc069c403ebaf9f0171e9517f40e41"'
          },
        );

        expect(
          headers.wwwAuthenticate?.parameters
              .firstWhere((p) => p.key == 'realm')
              .value,
          equals('Protected Area'),
        );
      });

      test('should parse qop parameter correctly', () async {
        var headers = await getServerRequestHeaders(
          server: server,
          headers: {
            'www-authenticate':
                'Digest realm="Protected Area", qop="auth", nonce="dcd98b7102dd2f0e8b11d0f600bfb0c093", opaque="5ccc069c403ebaf9f0171e9517f40e41"'
          },
        );

        expect(
          headers.wwwAuthenticate?.parameters
              .firstWhere((p) => p.key == 'qop')
              .value,
          equals('auth'),
        );
      });

      test('should parse nonce parameter correctly', () async {
        var headers = await getServerRequestHeaders(
          server: server,
          headers: {
            'www-authenticate':
                'Digest realm="Protected Area", qop="auth", nonce="dcd98b7102dd2f0e8b11d0f600bfb0c093", opaque="5ccc069c403ebaf9f0171e9517f40e41"'
          },
        );

        expect(
          headers.wwwAuthenticate?.parameters
              .firstWhere((p) => p.key == 'nonce')
              .value,
          equals('dcd98b7102dd2f0e8b11d0f600bfb0c093'),
        );
      });

      test('should parse opaque parameter correctly', () async {
        var headers = await getServerRequestHeaders(
          server: server,
          headers: {
            'www-authenticate':
                'Digest realm="Protected Area", qop="auth", nonce="dcd98b7102dd2f0e8b11d0f600bfb0c093", opaque="5ccc069c403ebaf9f0171e9517f40e41"'
          },
        );

        expect(
          headers.wwwAuthenticate?.parameters
              .firstWhere((p) => p.key == 'opaque')
              .value,
          equals('5ccc069c403ebaf9f0171e9517f40e41'),
        );
      });
    });

    group('when Bearer authentication', () {
      test('with realm parameter should parse scheme correctly', () async {
        var headers = await getServerRequestHeaders(
          server: server,
          headers: {'www-authenticate': 'Bearer realm="Protected API"'},
        );

        expect(headers.wwwAuthenticate?.scheme, equals('Bearer'));
      });

      test('with error parameter should parse error correctly', () async {
        var headers = await getServerRequestHeaders(
          server: server,
          headers: {
            'www-authenticate':
                'Bearer realm="Protected API", error="invalid_token"'
          },
        );

        expect(
          headers.wwwAuthenticate?.parameters
              .firstWhere((p) => p.key == 'error')
              .value,
          equals('invalid_token'),
        );
      });
    });

    test(
      'when no WWW-Authenticate header is passed then it should return null',
      () async {
        var headers = await getServerRequestHeaders(
          server: server,
          headers: {},
        );

        expect(headers.wwwAuthenticate_.valueOrNullIfInvalid, isNull);
        expect(() => headers.wwwAuthenticate,
            throwsA(isA<InvalidHeaderException>()));
      },
    );
  });

  group('Given a WWW-Authenticate header with the strict flag false', () {
    late RelicServer server;

    setUp(() async {
      server = await createServer(strictHeaders: false);
    });

    tearDown(() => server.close());

    test(
      'when an invalid header is passed then it should return null',
      () async {
        var headers = await getServerRequestHeaders(
          server: server,
          headers: {'www-authenticate': 'InvalidHeader'},
        );

        expect(headers.wwwAuthenticate_.valueOrNullIfInvalid, isNull);
        expect(() => headers.wwwAuthenticate,
            throwsA(isA<InvalidHeaderException>()));
      },
    );

    test(
      'when an invalid header is passed then it should be recorded in failedHeadersToParse',
      skip: 'todo: drop failedHeadersToParse',
      () async {
        var headers = await getServerRequestHeaders(
          server: server,
          headers: {'www-authenticate': 'InvalidHeader'},
        );

        expect(
          headers.failedHeadersToParse['www-authenticate'],
          equals(['InvalidHeader']),
        );
      },
    );
  });
}
