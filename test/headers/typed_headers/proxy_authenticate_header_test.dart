import 'package:test/test.dart';
import 'package:relic/src/headers/headers.dart';
import 'package:relic/src/relic_server.dart';

import '../headers_test_utils.dart';
import '../docs/strict_validation_docs.dart';

/// Reference: https://developer.mozilla.org/en-US/docs/Web/HTTP/Headers/Proxy-Authenticate
/// About empty value test, check the [StrictValidationDocs] class for more details.
void main() {
  group('Given a Proxy-Authenticate header with the strict flag true', () {
    late RelicServer server;

    setUp(() async {
      server = await createServer(strictHeaders: true);
    });

    tearDown(() => server.close());

    test(
      'when an empty Proxy-Authenticate header is passed then it should throw FormatException',
      () async {
        expect(
          () async => await getServerRequestHeaders(
            server: server,
            headers: {'proxy-authenticate': ''},
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
      'when a Proxy-Authenticate header with an invalid value is passed '
      'then the server does not respond with a bad request if the headers '
      'is not actually used',
      () async {
        Headers headers = await getServerRequestHeaders(
          server: server,
          headers: {'proxy-authenticate': 'Test'},
          parseAllHeaders: false,
        );

        expect(headers, isNotNull);
      },
    );

    group('when Basic authentication', () {
      test('with realm parameter should parse scheme correctly', () async {
        Headers headers = await getServerRequestHeaders(
          server: server,
          headers: {'proxy-authenticate': 'Basic realm="Proxy Realm"'},
        );

        expect(headers.proxyAuthenticate?.scheme, equals('Basic'));
      });

      test('with realm parameter should parse realm correctly', () async {
        Headers headers = await getServerRequestHeaders(
          server: server,
          headers: {'proxy-authenticate': 'Basic realm="Proxy Realm"'},
        );

        expect(
          headers.proxyAuthenticate?.parameters
              .firstWhere((p) => p.key == 'realm')
              .value,
          equals('Proxy Realm'),
        );
      });
    });

    group('when Digest authentication', () {
      test('should parse scheme correctly', () async {
        Headers headers = await getServerRequestHeaders(
          server: server,
          headers: {
            'proxy-authenticate':
                'Digest realm="Proxy Authentication Required"',
          },
        );

        expect(headers.proxyAuthenticate?.scheme, equals('Digest'));
      });

      test('should parse realm parameter correctly', () async {
        Headers headers = await getServerRequestHeaders(
          server: server,
          headers: {
            'proxy-authenticate':
                'Digest realm="Proxy Authentication Required"',
          },
        );

        expect(
          headers.proxyAuthenticate?.parameters
              .firstWhere((p) => p.key == 'realm')
              .value,
          equals('Proxy Authentication Required'),
        );
      });

      test('should parse qop parameter correctly', () async {
        Headers headers = await getServerRequestHeaders(
          server: server,
          headers: {
            'proxy-authenticate':
                'Digest realm="Proxy Authentication Required", qop="auth", nonce="dcd98b7102dd2f0e8b11d0f600bfb0c093", opaque="5ccc069c403ebaf9f0171e9517f40e41"'
          },
        );

        expect(
          headers.proxyAuthenticate?.parameters
              .firstWhere((p) => p.key == 'qop')
              .value,
          equals('auth'),
        );
      });

      test('should parse nonce parameter correctly', () async {
        Headers headers = await getServerRequestHeaders(
          server: server,
          headers: {
            'proxy-authenticate':
                'Digest realm="Proxy Authentication Required", qop="auth", nonce="dcd98b7102dd2f0e8b11d0f600bfb0c093", opaque="5ccc069c403ebaf9f0171e9517f40e41"'
          },
        );

        expect(
          headers.proxyAuthenticate?.parameters
              .firstWhere((p) => p.key == 'nonce')
              .value,
          equals('dcd98b7102dd2f0e8b11d0f600bfb0c093'),
        );
      });

      test('should parse opaque parameter correctly', () async {
        Headers headers = await getServerRequestHeaders(
          server: server,
          headers: {
            'proxy-authenticate':
                'Digest realm="Proxy Authentication Required", qop="auth", nonce="dcd98b7102dd2f0e8b11d0f600bfb0c093", opaque="5ccc069c403ebaf9f0171e9517f40e41"'
          },
        );

        expect(
          headers.proxyAuthenticate?.parameters
              .firstWhere((p) => p.key == 'opaque')
              .value,
          equals('5ccc069c403ebaf9f0171e9517f40e41'),
        );
      });
    });

    test(
      'when no Proxy-Authenticate header is passed then it should return null',
      () async {
        Headers headers = await getServerRequestHeaders(
          server: server,
          headers: {},
        );

        expect(headers.proxyAuthenticate, isNull);
      },
    );
  });

  group('Given a Proxy-Authenticate header with the strict flag false', () {
    late RelicServer server;

    setUp(() async {
      server = await createServer(strictHeaders: false);
    });

    tearDown(() => server.close());

    test(
      'when an invalid header is passed then it should return null',
      () async {
        Headers headers = await getServerRequestHeaders(
          server: server,
          headers: {'proxy-authenticate': 'InvalidHeader'},
        );

        expect(headers.proxyAuthenticate, isNull);
      },
    );

    test(
      'when an invalid header is passed then it should be recorded in failedHeadersToParse',
      () async {
        Headers headers = await getServerRequestHeaders(
          server: server,
          headers: {'proxy-authenticate': 'InvalidHeader'},
        );

        expect(
          headers.failedHeadersToParse['proxy-authenticate'],
          equals(['InvalidHeader']),
        );
      },
    );
  });
}
