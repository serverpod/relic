import 'package:relic/relic.dart';
import 'package:test/test.dart';
import 'package:relic/src/headers/standard_headers_extensions.dart';

import '../headers_test_utils.dart';
import '../docs/strict_validation_docs.dart';

/// Reference: https://developer.mozilla.org/en-US/docs/Web/HTTP/Headers/Permissions-Policy
/// About empty value test, check the [StrictValidationDocs] class for more details.
void main() {
  group('Given a Permissions-Policy header with the strict flag true',
      skip: 'drop strict mode', () {
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
          () async => await getServerRequestHeaders(
            server: server,
            headers: {'permissions-policy': ''},
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
      'when a Permissions-Policy header with an empty value is passed '
      'then the server does not respond with a bad request if the headers '
      'is not actually used',
      () async {
        var headers = await getServerRequestHeaders(
          server: server,
          headers: {'permissions-policy': ''},
          eagerParseHeaders: false,
        );

        expect(headers, isNotNull);
      },
    );

    test(
      'when a valid Permissions-Policy header is passed then it should parse the policies correctly',
      () async {
        var headers = await getServerRequestHeaders(
          server: server,
          headers: {'permissions-policy': 'geolocation=(self), microphone=()'},
        );

        final policies = headers.permissionsPolicy?.directives;
        expect(policies?.length, equals(2));
        expect(policies?[0].name, equals('geolocation'));
        expect(policies?[0].values, equals(['self']));
        expect(policies?[1].name, equals('microphone'));
        expect(policies?[1].values, equals(['']));
      },
    );

    test(
      'when a Permissions-Policy header with multiple policies is passed then it should parse correctly',
      () async {
        var headers = await getServerRequestHeaders(
          server: server,
          headers: {
            'permissions-policy':
                'geolocation=(self), camera=(self "https://example.com")'
          },
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
        var headers = await getServerRequestHeaders(
          server: server,
          headers: {},
        );

        expect(headers.permissionsPolicy_.valueOrNullIfInvalid, isNull);
        expect(() => headers.permissionsPolicy,
            throwsA(isA<InvalidHeaderException>()));
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
          var headers = await getServerRequestHeaders(
            server: server,
            headers: {'permissions-policy': ''},
          );

          expect(headers.permissionsPolicy_.valueOrNullIfInvalid, isNull);
          expect(() => headers.permissionsPolicy,
              throwsA(isA<InvalidHeaderException>()));
        },
      );

      test(
        'then it should be recorded in the "failedHeadersToParse" field',
        skip: 'todo: drop failedHeadersToParse',
        () async {
          var headers = await getServerRequestHeaders(
            server: server,
            headers: {'permissions-policy': ''},
          );

          expect(
            headers.failedHeadersToParse['permissions-policy'],
            equals(['']),
          );
        },
      );
    });
  });
}
