import 'package:relic/relic.dart';
import 'package:test/test.dart';

import '../docs/strict_validation_docs.dart';
import '../headers_test_utils.dart';

/// Reference: https://developer.mozilla.org/en-US/docs/Web/HTTP/Headers/Referrer-Policy
/// For more details on header validation behavior, see the [HeaderValidationDocs] class.
void main() {
  group('Given a Referrer-Policy header with validation', () {
    late RelicServer server;

    setUp(() async {
      server = await createServer();
    });

    tearDown(() => server.close());

    test(
      'when an empty Referrer-Policy header is passed then the server should respond with a bad request '
      'including a message that states the value cannot be empty',
      () async {
        expect(
          getServerRequestHeaders(
            server: server,
            touchHeaders: (final h) => h.referrerPolicy,
            headers: {'referrer-policy': ''},
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
      'when an invalid Referrer-Policy header is passed then the server should respond with a bad request '
      'including a message that states the value is invalid',
      () async {
        expect(
          getServerRequestHeaders(
            server: server,
            touchHeaders: (final h) => h.referrerPolicy,
            headers: {'referrer-policy': 'invalid-value'},
          ),
          throwsA(isA<BadRequestException>().having(
            (final e) => e.message,
            'message',
            contains('Invalid value'),
          )),
        );
      },
    );

    test(
      'when a Referrer-Policy header with an invalid value is passed '
      'then the server does not respond with a bad request if the headers '
      'is not actually used',
      () async {
        final headers = await getServerRequestHeaders(
          server: server,
          touchHeaders: (final _) {},
          headers: {'referrer-policy': 'invalid-value'},
        );

        expect(headers, isNotNull);
      },
    );

    test(
      'when a valid Referrer-Policy header is passed then it should parse the policy correctly',
      () async {
        final headers = await getServerRequestHeaders(
          server: server,
          touchHeaders: (final h) => h.referrerPolicy,
          headers: {'referrer-policy': 'no-referrer'},
        );

        expect(headers.referrerPolicy?.directive, equals('no-referrer'));
      },
    );

    test(
      'when no Referrer-Policy header is passed then it should return null',
      () async {
        final headers = await getServerRequestHeaders(
          server: server,
          touchHeaders: (final h) => h.referrerPolicy,
          headers: {},
        );

        expect(headers.referrerPolicy, isNull);
      },
    );
  });

  group('Given a Referrer-Policy header without validation', () {
    late RelicServer server;

    setUp(() async {
      server = await createServer();
    });

    tearDown(() => server.close());

    group('when an empty Referrer-Policy header is passed', () {
      test(
        'then it should return null',
        () async {
          final headers = await getServerRequestHeaders(
            server: server,
            touchHeaders: (final _) {},
            headers: {'referrer-policy': ''},
          );

          expect(Headers.referrerPolicy[headers].valueOrNullIfInvalid, isNull);
          expect(() => headers.referrerPolicy, throwsInvalidHeader);
        },
      );
    });
  });
}
