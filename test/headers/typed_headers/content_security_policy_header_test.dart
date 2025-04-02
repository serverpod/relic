import 'package:relic/relic.dart';
import 'package:test/test.dart';
import 'package:relic/src/headers/standard_headers_extensions.dart';

import '../headers_test_utils.dart';
import '../docs/strict_validation_docs.dart';

/// Reference: https://developer.mozilla.org/en-US/docs/Web/HTTP/Headers/Content-Security-Policy
/// About empty value test, check the [StrictValidationDocs] class for more details.
void main() {
  group('Given a Content-Security-Policy header with the strict flag true', () {
    late RelicServer server;

    setUp(() async {
      server = await createServer(strictHeaders: true);
    });

    tearDown(() => server.close());

    test(
      'when an empty Content-Security-Policy header is passed then the server should respond with a bad request '
      'including a message that states the value cannot be empty',
      () async {
        expect(
          getServerRequestHeaders(
            server: server,
            touchHeaders: (h) => h.contentSecurityPolicy,
            headers: {'content-security-policy': ''},
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
      'when a Content-Security-Policy header with an empty value is passed '
      'then the server does not respond with a bad request if the headers '
      'is not actually used',
      () async {
        var headers = await getServerRequestHeaders(
          server: server,
          touchHeaders: (_) {},
          headers: {'content-security-policy': ''},
        );

        expect(headers, isNotNull);
      },
    );

    test(
      'when a valid Content-Security-Policy header is passed then it should parse the directives correctly',
      () async {
        var headers = await getServerRequestHeaders(
          server: server,
          touchHeaders: (_) {},
          headers: {
            'content-security-policy': "default-src 'self'; script-src 'none'"
          },
        );

        final csp = headers.contentSecurityPolicy;
        expect(csp?.directives.length, equals(2));
        expect(csp?.directives[0].name, equals('default-src'));
        expect(csp?.directives[0].values, equals(["'self'"]));
        expect(csp?.directives[1].name, equals('script-src'));
        expect(csp?.directives[1].values, equals(["'none'"]));
      },
    );

    test(
      'when a Content-Security-Policy header with multiple directives is passed then it should parse correctly',
      () async {
        var headers = await getServerRequestHeaders(
          server: server,
          touchHeaders: (_) {},
          headers: {
            'content-security-policy':
                "default-src 'self'; img-src *; media-src media1.com media2.com"
          },
        );

        final csp = headers.contentSecurityPolicy;
        expect(csp?.directives.length, equals(3));
        expect(csp?.directives[0].name, equals('default-src'));
        expect(csp?.directives[0].values, equals(["'self'"]));
        expect(csp?.directives[1].name, equals('img-src'));
        expect(csp?.directives[1].values, equals(['*']));
        expect(csp?.directives[2].name, equals('media-src'));
        expect(csp?.directives[2].values, equals(['media1.com', 'media2.com']));
      },
    );

    test(
      'when no Content-Security-Policy header is passed then it should return null',
      () async {
        var headers = await getServerRequestHeaders(
          server: server,
          touchHeaders: (h) => h.contentSecurityPolicy,
          headers: {},
        );

        expect(headers.contentSecurityPolicy, isNull);
      },
    );
  });

  group('Given a Content-Security-Policy header with the strict flag false',
      () {
    late RelicServer server;

    setUp(() async {
      server = await createServer(strictHeaders: false);
    });

    tearDown(() => server.close());

    group('when an empty Content-Security-Policy header is passed', () {
      test(
        'then it should return null',
        () async {
          var headers = await getServerRequestHeaders(
            server: server,
            touchHeaders: (_) {},
            headers: {'content-security-policy': ''},
          );

          expect(Headers.contentSecurityPolicy[headers].valueOrNullIfInvalid,
              isNull);
          expect(() => headers.contentSecurityPolicy, throwsInvalidHeader);
        },
      );
    });
  });
}
