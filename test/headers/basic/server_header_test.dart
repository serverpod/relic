import 'package:relic/relic.dart';
import 'package:test/test.dart';
import 'package:relic/src/headers/standard_headers_extensions.dart';
import '../headers_test_utils.dart';
import '../docs/strict_validation_docs.dart';

/// Reference: https://developer.mozilla.org/en-US/docs/Web/HTTP/Headers/Server
/// About empty value test, check the [StrictValidationDocs] class for more details.
void main() {
  group(
    'Given a Server header with the strict flag true',
    () {
      late RelicServer server;

      setUp(() async {
        server = await createServer(strictHeaders: true);
      });

      tearDown(() => server.close());

      test(
        'when an empty Server header is passed then the server responds '
        'with a bad request including a message that states the header value '
        'cannot be empty',
        () async {
          expect(
            () async => await getServerRequestHeaders(
              server: server,
              headers: {'server': ''},
              touchHeaders: (h) => h.server,
            ),
            throwsA(
              isA<BadRequestException>().having(
                (e) => e.message,
                'message',
                contains('Value cannot be empty'),
              ),
            ),
          );
        },
      );

      test(
        'when a Server header with an empty value is passed '
        'then the server does not respond with a bad request if the headers '
        'is not actually used',
        () async {
          var headers = await getServerRequestHeaders(
            server: server,
            touchHeaders: (_) {},
            headers: {'server': ''},
          );

          expect(headers, isNotNull);
        },
      );

      test(
        'when a valid Server header is passed then it should parse the server correctly',
        () async {
          var headers = await getServerRequestHeaders(
            server: server,
            touchHeaders: (_) {},
            headers: {'server': 'MyServer/1.0'},
          );

          expect(headers.server, equals('MyServer/1.0'));
        },
      );

      test(
        'when a Server header with extra whitespace is passed then it should parse the server correctly',
        () async {
          var headers = await getServerRequestHeaders(
            server: server,
            headers: {'server': ' MyServer/1.0 '},
            touchHeaders: (h) => h.server,
          );

          expect(headers.server, equals('MyServer/1.0'));
        },
      );

      test(
        'when no Server header is passed then it should return null',
        () async {
          var headers = await getServerRequestHeaders(
            server: server,
            headers: {},
            touchHeaders: (h) => h.server,
          );

          expect(headers.server, isNull);
        },
      );
    },
  );

  group('Given a Server header with the strict flag false', () {
    late RelicServer server;

    setUp(() async {
      server = await createServer(strictHeaders: false);
    });

    tearDown(() => server.close());

    group('when an empty Server header is passed', () {
      test(
        'then it should return null',
        () async {
          var headers = await getServerRequestHeaders(
            server: server,
            touchHeaders: (_) {},
            headers: {'server': ''},
          );

          expect(headers.server_.valueOrNullIfInvalid, isNull);
          expect(() => headers.server, throwsA(isA<InvalidHeaderException>()));
        },
      );
    });
  });
}
