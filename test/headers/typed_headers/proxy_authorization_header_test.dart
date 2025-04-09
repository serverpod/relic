import 'dart:convert';

import 'package:relic/relic.dart';
import 'package:relic/src/headers/standard_headers_extensions.dart';
import 'package:test/test.dart';

import '../docs/strict_validation_docs.dart';
import '../headers_test_utils.dart';

/// Reference: https://developer.mozilla.org/en-US/docs/Web/HTTP/Headers/Proxy-Authorization
/// About empty value test, check the [StrictValidationDocs] class for more details.
void main() {
  group('Given a Proxy-Authorization header with the strict flag true', () {
    late RelicServer server;

    setUp(() async {
      server = await createServer(strictHeaders: true);
    });

    tearDown(() => server.close());

    test(
      'when an empty Proxy-Authorization header is passed then the server '
      'responds with a bad request including a message that states the header '
      'value cannot be empty',
      () async {
        expect(
          getServerRequestHeaders(
            server: server,
            touchHeaders: (final h) => h.proxyAuthorization,
            headers: {'proxy-authorization': ''},
          ),
          throwsA(
            isA<BadRequestException>().having(
              (final e) => e.message,
              'message',
              contains('Value cannot be empty'),
            ),
          ),
        );
      },
    );

    test(
      'when a Proxy-Authorization header with an invalid value is passed '
      'then the server does not respond with a bad request if the headers '
      'is not actually used',
      () async {
        final headers = await getServerRequestHeaders(
          server: server,
          touchHeaders: (final _) {},
          headers: {
            'proxy-authorization': 'invalid-proxy-authorization-format'
          },
        );

        expect(headers, isNotNull);
      },
    );

    test(
      'when no Proxy-Authorization header is passed then it should default to null',
      () async {
        final headers = await getServerRequestHeaders(
          server: server,
          headers: {},
          touchHeaders: (final h) => h.proxyAuthorization,
        );

        expect(headers.proxyAuthorization, isNull);
      },
    );

    group('and a Bearer Authorization header', () {
      test(
        'when an invalid Bearer token is passed then the server responds with a '
        'bad request including a message that states the token format is invalid',
        () async {
          expect(
            getServerRequestHeaders(
              server: server,
              touchHeaders: (final h) => h.proxyAuthorization,
              headers: {'proxy-authorization': 'Bearer'},
            ),
            throwsA(
              isA<BadRequestException>().having(
                (final e) => e.message,
                'message',
                contains('Invalid bearer prefix'),
              ),
            ),
          );
        },
      );

      test(
        'when a Bearer token is passed then it should parse the token correctly',
        () async {
          final headers = await getServerRequestHeaders(
            server: server,
            touchHeaders: (final h) => h.proxyAuthorization,
            headers: {'proxy-authorization': 'Bearer validToken123'},
          );
          expect(
            headers.proxyAuthorization,
            isA<BearerAuthorizationHeader>().having(
              (final auth) => auth.token,
              'token',
              'validToken123',
            ),
          );
        },
      );
    });

    group('and a Basic Authorization header', () {
      test(
        'when an invalid Basic token is passed then the server responds with a '
        'bad request including a message that states the token format is invalid',
        () async {
          expect(
            getServerRequestHeaders(
              server: server,
              touchHeaders: (final h) => h.proxyAuthorization,
              headers: {'proxy-authorization': 'Basic invalidBase64'},
            ),
            throwsA(
              isA<BadRequestException>().having(
                (final e) => e.message,
                'message',
                contains('Invalid basic token format'),
              ),
            ),
          );
        },
      );

      test(
        'when a Basic token is passed then it should parse the credentials '
        'correctly',
        () async {
          final credentials = base64Encode(utf8.encode('user:pass'));
          final headers = await getServerRequestHeaders(
            server: server,
            touchHeaders: (final h) => h.proxyAuthorization,
            headers: {'proxy-authorization': 'Basic $credentials'},
          );
          expect(
            headers.proxyAuthorization,
            isA<BasicAuthorizationHeader>()
                .having((final auth) => auth.username, 'username', 'user')
                .having((final auth) => auth.password, 'password', 'pass'),
          );
        },
      );
    });

    group('and a Digest Authorization header', () {
      test(
        'when an invalid Digest token is passed then the server responds with a '
        'bad request including a message that states the token format is invalid',
        () async {
          expect(
            getServerRequestHeaders(
              server: server,
              touchHeaders: (final h) => h.proxyAuthorization,
              headers: {'proxy-authorization': 'Digest invalidFormat'},
            ),
            throwsA(
              isA<BadRequestException>().having(
                (final e) => e.message,
                'message',
                contains('Invalid digest token format'),
              ),
            ),
          );
        },
      );

      group('when a Digest token is passed with missing', () {
        test(
          '"username" then the server responds with a bad request including '
          'a message that states the username is required',
          () async {
            const digestValue =
                'missingUsername="user", realm="realm", nonce="nonce", uri="/", response="response"';

            expect(
              getServerRequestHeaders(
                server: server,
                touchHeaders: (final h) => h.proxyAuthorization,
                headers: {'proxy-authorization': 'Digest $digestValue'},
              ),
              throwsA(
                isA<BadRequestException>().having(
                  (final e) => e.message,
                  'message',
                  contains('Username is required and cannot be empty'),
                ),
              ),
            );
          },
        );
        test(
          '"realm" then the server responds with a bad request including '
          'a message that states the realm is required',
          () async {
            const digestValue =
                'username="user", missingRealm="realm", nonce="nonce", uri="/", response="response"';

            expect(
              getServerRequestHeaders(
                server: server,
                touchHeaders: (final h) => h.proxyAuthorization,
                headers: {'proxy-authorization': 'Digest $digestValue'},
              ),
              throwsA(
                isA<BadRequestException>().having(
                  (final e) => e.message,
                  'message',
                  contains('Realm is required and cannot be empty'),
                ),
              ),
            );
          },
        );

        test(
          '"nonce" then the server responds with a bad request including '
          'a message that states the nonce is required',
          () async {
            const digestValue =
                'username="user", realm="realm", missingNonce="nonce", uri="/", response="response"';

            expect(
              getServerRequestHeaders(
                server: server,
                touchHeaders: (final h) => h.proxyAuthorization,
                headers: {'proxy-authorization': 'Digest $digestValue'},
              ),
              throwsA(
                isA<BadRequestException>().having(
                  (final e) => e.message,
                  'message',
                  contains('Nonce is required and cannot be empty'),
                ),
              ),
            );
          },
        );

        test(
          '"uri" then the server responds with a bad request including '
          'a message that states the uri is required',
          () async {
            const digestValue =
                'username="user", realm="realm", nonce="nonce", missingUri="/", response="response"';

            expect(
              getServerRequestHeaders(
                server: server,
                touchHeaders: (final h) => h.proxyAuthorization,
                headers: {'proxy-authorization': 'Digest $digestValue'},
              ),
              throwsA(
                isA<BadRequestException>().having(
                  (final e) => e.message,
                  'message',
                  contains('URI is required and cannot be empty'),
                ),
              ),
            );
          },
        );

        test(
          '"response" then the server responds with a bad request including '
          'a message that states the response is required',
          () async {
            const digestValue =
                'username="user", realm="realm", nonce="nonce", uri="/", missingResponse="response"';

            expect(
              getServerRequestHeaders(
                server: server,
                touchHeaders: (final h) => h.proxyAuthorization,
                headers: {'proxy-authorization': 'Digest $digestValue'},
              ),
              throwsA(
                isA<BadRequestException>().having(
                  (final e) => e.message,
                  'message',
                  contains('Response is required and cannot be empty'),
                ),
              ),
            );
          },
        );
      });

      group('when a Digest token is passed with empty', () {
        test(
          '"username" then the server responds with a bad request including '
          'a message that states the username is required',
          () async {
            const digestValue =
                'username="", realm="realm", nonce="nonce", uri="/", response="response"';

            expect(
              getServerRequestHeaders(
                server: server,
                touchHeaders: (final h) => h.proxyAuthorization,
                headers: {'proxy-authorization': 'Digest $digestValue'},
              ),
              throwsA(
                isA<BadRequestException>().having(
                  (final e) => e.message,
                  'message',
                  contains('Username is required and cannot be empty'),
                ),
              ),
            );
          },
        );
        test(
          '"realm" then the server responds with a bad request including '
          'a message that states the realm is required',
          () async {
            const digestValue =
                'username="user", realm="", nonce="nonce", uri="/", response="response"';

            expect(
              getServerRequestHeaders(
                server: server,
                touchHeaders: (final h) => h.proxyAuthorization,
                headers: {'proxy-authorization': 'Digest $digestValue'},
              ),
              throwsA(
                isA<BadRequestException>().having(
                  (final e) => e.message,
                  'message',
                  contains('Realm is required and cannot be empty'),
                ),
              ),
            );
          },
        );

        test(
          '"nonce" then the server responds with a bad request including '
          'a message that states the nonce is required',
          () async {
            const digestValue =
                'username="user", realm="realm", nonce="", uri="/", response="response"';

            expect(
              getServerRequestHeaders(
                server: server,
                touchHeaders: (final h) => h.proxyAuthorization,
                headers: {'proxy-authorization': 'Digest $digestValue'},
              ),
              throwsA(
                isA<BadRequestException>().having(
                  (final e) => e.message,
                  'message',
                  contains('Nonce is required and cannot be empty'),
                ),
              ),
            );
          },
        );

        test(
          '"uri" then the server responds with a bad request including '
          'a message that states the uri is required',
          () async {
            const digestValue =
                'username="user", realm="realm", nonce="nonce", uri="", response="response"';

            expect(
              getServerRequestHeaders(
                server: server,
                touchHeaders: (final h) => h.proxyAuthorization,
                headers: {'proxy-authorization': 'Digest $digestValue'},
              ),
              throwsA(
                isA<BadRequestException>().having(
                  (final e) => e.message,
                  'message',
                  contains('URI is required and cannot be empty'),
                ),
              ),
            );
          },
        );

        test(
          '"response" then the server responds with a bad request including '
          'a message that states the response is required',
          () async {
            const digestValue =
                'username="user", realm="realm", nonce="nonce", uri="/", response=""';

            expect(
              getServerRequestHeaders(
                server: server,
                touchHeaders: (final h) => h.proxyAuthorization,
                headers: {'proxy-authorization': 'Digest $digestValue'},
              ),
              throwsA(
                isA<BadRequestException>().having(
                  (final e) => e.message,
                  'message',
                  contains('Response is required and cannot be empty'),
                ),
              ),
            );
          },
        );
      });

      test(
        'when a Digest token is passed with all required parameters then it '
        'should parse the credentials correctly',
        () async {
          const digestValue =
              'username="user", realm="realm", nonce="nonce", uri="/", response="response"';
          final headers = await getServerRequestHeaders(
            server: server,
            touchHeaders: (final h) => h.proxyAuthorization,
            headers: {'proxy-authorization': 'Digest $digestValue'},
          );
          expect(
              headers.proxyAuthorization,
              isA<DigestAuthorizationHeader>()
                  .having((final auth) => auth.username, 'username', 'user')
                  .having((final auth) => auth.realm, 'realm', 'realm')
                  .having((final auth) => auth.nonce, 'nonce', 'nonce')
                  .having((final auth) => auth.uri, 'uri', '/')
                  .having(
                      (final auth) => auth.response, 'response', 'response'));
        },
      );

      test(
        'when a Digest token is passed then it should parse the credentials correctly',
        () async {
          const digestValue =
              'username="user", realm="realm", nonce="nonce", uri="/", response="response", algorithm="MD5", qop="auth", nc="00000001", cnonce="cnonce", opaque="opaque"';
          final headers = await getServerRequestHeaders(
            server: server,
            touchHeaders: (final h) => h.proxyAuthorization,
            headers: {'proxy-authorization': 'Digest $digestValue'},
          );
          expect(
            headers.proxyAuthorization,
            isA<DigestAuthorizationHeader>()
                .having((final auth) => auth.username, 'username', 'user')
                .having((final auth) => auth.realm, 'realm', 'realm')
                .having((final auth) => auth.nonce, 'nonce', 'nonce')
                .having((final auth) => auth.uri, 'uri', '/')
                .having((final auth) => auth.response, 'response', 'response')
                .having((final auth) => auth.algorithm, 'algorithm', 'MD5')
                .having((final auth) => auth.qop, 'qop', 'auth')
                .having((final auth) => auth.nc, 'nc', '00000001')
                .having((final auth) => auth.cnonce, 'cnonce', 'cnonce')
                .having((final auth) => auth.opaque, 'opaque', 'opaque'),
          );
        },
      );
    });
  });

  group('Given a Proxy-Authorization header with the strict flag false', () {
    late RelicServer server;

    setUp(() async {
      server = await createServer(strictHeaders: false);
    });

    tearDown(() => server.close());

    group('when an empty Proxy-Authorization header is passed', () {
      test(
        'then it should return null',
        () async {
          final headers = await getServerRequestHeaders(
            server: server,
            touchHeaders: (final _) {},
            headers: {'proxy-authorization': ''},
          );
          expect(
              Headers.proxyAuthorization[headers].valueOrNullIfInvalid, isNull);
          expect(() => headers.proxyAuthorization, throwsInvalidHeader);
        },
      );
    });

    group('when an invalid Proxy-Authorization header is passed', () {
      test(
        'then it should return null',
        () async {
          final headers = await getServerRequestHeaders(
            server: server,
            touchHeaders: (final _) {},
            headers: {'proxy-authorization': 'InvalidFormat'},
          );

          expect(
              Headers.proxyAuthorization[headers].valueOrNullIfInvalid, isNull);
          expect(() => headers.proxyAuthorization, throwsInvalidHeader);
        },
      );
    });
  });
}
