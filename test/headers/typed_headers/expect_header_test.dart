import 'package:relic/relic.dart';
import 'package:test/test.dart';

import '../docs/strict_validation_docs.dart';
import '../headers_test_utils.dart';

/// Reference: https://developer.mozilla.org/en-US/docs/Web/HTTP/Headers/Expect
/// About empty value test, check the [StrictValidationDocs] class for more details.
void main() {
  group('Given an Expect header with the strict flag true', () {
    late RelicServer server;

    setUp(() async {
      server = await createServer(strictHeaders: true);
    });

    tearDown(() => server.close());

    test(
      'when an empty Expect header is passed then the server responds '
      'with a bad request including a message that states the header value '
      'cannot be empty',
      () async {
        expect(
          getServerRequestHeaders(
            server: server,
            touchHeaders: (final h) => h.expect,
            headers: {'expect': ''},
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
      'when an invalid Expect header is passed then the server should respond with a bad request '
      'including a message that states the value is invalid',
      () async {
        expect(
          getServerRequestHeaders(
            server: server,
            touchHeaders: (final h) => h.expect,
            headers: {'expect': 'custom-directive'},
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
      'when an Expect header with an invalid value is passed '
      'then the server does not respond with a bad request if the headers '
      'is not actually used',
      () async {
        final headers = await getServerRequestHeaders(
          server: server,
          touchHeaders: (final _) {},
          headers: {'expect': 'custom-directive'},
        );

        expect(headers, isNotNull);
      },
    );

    test(
      'when a valid Expect header is passed then it should parse the directives correctly',
      () async {
        final headers = await getServerRequestHeaders(
          server: server,
          touchHeaders: (final h) => h.expect,
          headers: {'expect': '100-continue'},
        );

        expect(
          headers.expect?.value,
          contains('100-continue'),
        );
      },
    );
  });

  group('Given an Expect header with the strict flag false', () {
    late RelicServer server;

    setUp(() async {
      server = await createServer(strictHeaders: false);
    });

    tearDown(() => server.close());

    group('when an empty Expect header is passed', () {
      test(
        'then it should return null',
        () async {
          final headers = await getServerRequestHeaders(
            server: server,
            touchHeaders: (final _) {},
            headers: {'expect': ''},
          );

          expect(Headers.expect[headers].valueOrNullIfInvalid, isNull);
          expect(() => headers.expect, throwsInvalidHeader);
        },
      );
    });
  });
}
