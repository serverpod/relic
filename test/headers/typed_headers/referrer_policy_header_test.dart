import 'package:test/test.dart';
import 'package:relic/src/headers/headers.dart';
import 'package:relic/src/relic_server.dart';

import '../headers_test_utils.dart';
import '../docs/strict_validation_docs.dart';

/// Reference: https://developer.mozilla.org/en-US/docs/Web/HTTP/Headers/Referrer-Policy
/// About empty value test, check the [StrictValidationDocs] class for more details.
void main() {
  group('Given a Referrer-Policy header with the strict flag true', () {
    late RelicServer server;

    setUp(() async {
      server = await createServer(strictHeaders: true);
    });

    tearDown(() => server.close());

    test(
      'when an empty Referrer-Policy header is passed then the server should respond with a bad request '
      'including a message that states the value cannot be empty',
      () async {
        expect(
          () async => await getServerRequestHeaders(
            server: server,
            headers: {'referrer-policy': ''},
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
      'when an invalid Referrer-Policy header is passed then the server should respond with a bad request '
      'including a message that states the value is invalid',
      () async {
        expect(
          () async => await getServerRequestHeaders(
            server: server,
            headers: {'referrer-policy': 'invalid-value'},
          ),
          throwsA(isA<BadRequestException>().having(
            (e) => e.message,
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
        Headers headers = await getServerRequestHeaders(
          server: server,
          headers: {'referrer-policy': 'invalid-value'},
          parseAllHeaders: false,
        );

        expect(headers, isNotNull);
      },
    );

    test(
      'when a valid Referrer-Policy header is passed then it should parse the policy correctly',
      () async {
        Headers headers = await getServerRequestHeaders(
          server: server,
          headers: {'referrer-policy': 'no-referrer'},
        );

        expect(headers.referrerPolicy?.directive, equals('no-referrer'));
      },
    );

    test(
      'when no Referrer-Policy header is passed then it should return null',
      () async {
        Headers headers = await getServerRequestHeaders(
          server: server,
          headers: {},
        );

        expect(headers.referrerPolicy, isNull);
      },
    );
  });

  group('Given a Referrer-Policy header with the strict flag false', () {
    late RelicServer server;

    setUp(() async {
      server = await createServer(strictHeaders: false);
    });

    tearDown(() => server.close());

    group('when an empty Referrer-Policy header is passed', () {
      test(
        'then it should return null',
        () async {
          Headers headers = await getServerRequestHeaders(
            server: server,
            headers: {'referrer-policy': ''},
          );

          expect(headers.referrerPolicy, isNull);
        },
      );
      test(
        'then it should be recorded in the "failedHeadersToParse" field',
        () async {
          Headers headers = await getServerRequestHeaders(
            server: server,
            headers: {'referrer-policy': ''},
          );

          expect(
            headers.failedHeadersToParse['referrer-policy'],
            equals(['']),
          );
        },
      );
    });
  });
}
