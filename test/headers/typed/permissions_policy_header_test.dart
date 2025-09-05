import 'package:relic/relic.dart';
import 'package:test/test.dart';

import '../docs/strict_validation_docs.dart';
import '../headers_test_utils.dart';

/// Reference: https://developer.mozilla.org/en-US/docs/Web/HTTP/Headers/Permissions-Policy
/// About empty value test, check the [StrictValidationDocs] class for more details.
void main() {
  group('Given a Permissions-Policy header with the strict flag true', () {
    late RelicServer server;

    setUp(() async {
      server = await createServer(strictHeaders: true);
    });

    tearDown(() => server.close());

    test(
      'when an empty Permissions-Policy header is passed then the server should respond with a bad request '
      'including a message that states the value cannot be empty',
      () async {
        expect(
          getServerRequestHeaders(
            server: server,
            touchHeaders: (final h) => h.permissionsPolicy,
            headers: {'permissions-policy': ''},
          ),
          throwsA(isA<BadRequestException>().having(
            (final e) => e.message,
            'message',
            contains('Value cannot be empty'),
          )),
        );
      },
    );

    test(
      'when a Permissions-Policy header with an empty value is passed '
      'then the server does not respond with a bad request if the headers '
      'is not actually used',
      () async {
        final headers = await getServerRequestHeaders(
          server: server,
          touchHeaders: (final _) {},
          headers: {'permissions-policy': ''},
        );

        expect(headers, isNotNull);
      },
    );

    test(
      'when a valid Permissions-Policy header is passed then it should parse the policies correctly',
      () async {
        final headers = await getServerRequestHeaders(
          server: server,
          touchHeaders: (final h) => h.permissionsPolicy,
          headers: {'permissions-policy': 'geolocation=(self), microphone=()'},
        );

        final policies = headers.permissionsPolicy?.directives;
        expect(policies?.length, equals(2));
        expect(policies?[0].name, equals('geolocation'));
        expect(policies?[0].values, equals(['self']));
        expect(policies?[1].name, equals('microphone'));
        expect(policies?[1].values, isEmpty);
      },
    );

    test(
      'when a Permissions-Policy header with multiple policies is passed then it should parse correctly',
      () async {
        final headers = await getServerRequestHeaders(
          server: server,
          headers: {
            'permissions-policy':
                'geolocation=(self), camera=(self "https://example.com")'
          },
          touchHeaders: (final h) => h.permissionsPolicy,
        );

        final policies = headers.permissionsPolicy?.directives;
        expect(policies?.length, equals(2));
        expect(policies?[0].name, equals('geolocation'));
        expect(policies?[0].values, equals(['self']));
        expect(policies?[1].name, equals('camera'));
        expect(policies?[1].values, equals(['self', '"https://example.com"']));
      },
    );

    test(
      'when no Permissions-Policy header is passed then it should return null',
      () async {
        final headers = await getServerRequestHeaders(
          server: server,
          headers: {},
          touchHeaders: (final h) => h.permissionsPolicy,
        );

        expect(headers.permissionsPolicy, isNull);
      },
    );
  });

  group('Given a Permissions-Policy header with the strict flag false', () {
    late RelicServer server;

    setUp(() async {
      server = await createServer(strictHeaders: false);
    });

    tearDown(() => server.close());

    group('when an empty Permissions-Policy header is passed', () {
      test(
        'then it should return null',
        () async {
          final headers = await getServerRequestHeaders(
            server: server,
            touchHeaders: (final _) {},
            headers: {'permissions-policy': ''},
          );

          expect(
              Headers.permissionsPolicy[headers].valueOrNullIfInvalid, isNull);
          expect(() => headers.permissionsPolicy, throwsInvalidHeader);
        },
      );
    });
  });
}
