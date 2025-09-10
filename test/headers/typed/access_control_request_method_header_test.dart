import 'package:relic/relic.dart';
import 'package:test/test.dart';

import '../docs/strict_validation_docs.dart';
import '../headers_test_utils.dart';

/// Reference: https://developer.mozilla.org/en-US/docs/Web/HTTP/Headers/Access-Control-Request-Method
/// For more details on header validation behavior, see the [HeaderValidationDocs] class.
void main() {
  group('Given an Access-Control-Request-Method header with validation', () {
    late RelicServer server;

    setUp(() async {
      server = await createServer();
    });

    tearDown(() => server.close());

    test(
      'when an empty Access-Control-Request-Method header is passed then the '
      'server responds with a bad request including a message that states the '
      'header value cannot be empty',
      () async {
        expect(
          getServerRequestHeaders(
            server: server,
            touchHeaders: (final h) => h.accessControlRequestMethod,
            headers: {'access-control-request-method': ''},
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
      'when an invalid method is passed then the server responds '
      'with a bad request including a message that states the header value '
      'is invalid',
      () async {
        expect(
          getServerRequestHeaders(
            server: server,
            touchHeaders: (final h) => h.accessControlRequestMethod,
            headers: {'access-control-request-method': 'CUSTOM'},
          ),
          throwsA(
            isA<BadRequestException>().having(
              (final e) => e.message,
              'message',
              contains('Invalid value'),
            ),
          ),
        );
      },
    );

    test(
      'when an Access-Control-Request-Method header with an invalid value is '
      'passed then the server does not respond with a bad request if the '
      'headers is not actually used',
      () async {
        final headers = await getServerRequestHeaders(
          server: server,
          touchHeaders: (final _) {},
          headers: {'access-control-request-method': 'TEST'},
        );

        expect(headers, isNotNull);
      },
    );

    test(
      'when a valid Access-Control-Request-Method header is passed then it '
      'should parse the method correctly',
      () async {
        final headers = await getServerRequestHeaders(
          server: server,
          touchHeaders: (final h) => h.accessControlRequestMethod,
          headers: {'access-control-request-method': 'POST'},
        );

        expect(
          headers.accessControlRequestMethod,
          equals(RequestMethod.post),
        );
      },
    );

    test(
      'when an Access-Control-Request-Method header with extra whitespace is '
      'passed then it should parse the method correctly',
      () async {
        final headers = await getServerRequestHeaders(
          server: server,
          touchHeaders: (final h) => h.accessControlRequestMethod,
          headers: {'access-control-request-method': ' POST '},
        );

        expect(headers.accessControlRequestMethod, equals(RequestMethod.post));
      },
    );

    test(
      'when no Access-Control-Request-Method header is passed then it should '
      'default to null',
      () async {
        final headers = await getServerRequestHeaders(
          server: server,
          headers: {},
          touchHeaders: (final h) => h.accessControlRequestMethod,
        );

        expect(headers.accessControlRequestMethod, isNull);
      },
    );
  });

  group('Given an Access-Control-Request-Method header without validation', () {
    late RelicServer server;

    setUp(() async {
      server = await createServer();
    });

    tearDown(() => server.close());

    group('when an empty Access-Control-Request-Method header is passed', () {
      test(
        'then it should return null',
        () async {
          final headers = await getServerRequestHeaders(
            server: server,
            touchHeaders: (final _) {},
            headers: {'access-control-request-method': ''},
          );

          expect(
              Headers.accessControlRequestMethod[headers].valueOrNullIfInvalid,
              isNull);
          expect(() => headers.accessControlRequestMethod, throwsInvalidHeader);
        },
      );
    });
  });
}
