import 'package:relic/relic.dart';
import 'package:test/test.dart';
import 'package:relic/src/headers/standard_headers_extensions.dart';
import '../headers_test_utils.dart';
import '../docs/strict_validation_docs.dart';

/// Reference: https://developer.mozilla.org/en-US/docs/Web/HTTP/Headers/Via
/// About empty value test, check the [StrictValidationDocs] class for more details.
void main() {
  group('Given a Via header with the strict flag true',
      skip: 'drop strict mode', () {
    late RelicServer server;

    setUp(() async {
      server = await createServer(strictHeaders: true);
    });

    tearDown(() => server.close());
    test(
      'when an empty Via header is passed then the server responds '
      'with a bad request including a message that states the header value '
      'cannot be empty',
      () async {
        expect(
          () async => await getServerRequestHeaders(
            server: server,
            headers: {'via': ''},
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
      'when a Via header with an empty value is passed '
      'then the server does not respond with a bad request if the headers '
      'is not actually used',
      () async {
        var headers = await getServerRequestHeaders(
          server: server,
          headers: {'via': ''},
          eagerParseHeaders: false,
        );

        expect(headers, isNotNull);
      },
    );

    test(
      'when a valid Via header is passed then it should parse the values correctly',
      () async {
        var headers = await getServerRequestHeaders(
          server: server,
          headers: {'via': '1.1 example.com, 1.0 another.com'},
        );

        expect(headers.via, equals(['1.1 example.com', '1.0 another.com']));
      },
    );

    test(
      'when a Via header with extra whitespace is passed then it should parse the values correctly',
      () async {
        var headers = await getServerRequestHeaders(
          server: server,
          headers: {'via': ' 1.1 example.com , 1.0 another.com '},
        );

        expect(headers.via, equals(['1.1 example.com', '1.0 another.com']));
      },
    );

    test(
      'when a Via header with duplicate values is passed then it should parse '
      'the values correctly and remove duplicates',
      () async {
        var headers = await getServerRequestHeaders(
          server: server,
          headers: {'via': '1.1 example.com, 1.0 another.com, 1.0 another.com'},
        );

        expect(headers.via, equals(['1.1 example.com', '1.0 another.com']));
      },
    );

    test(
      'when no Via header is passed then it should return null',
      () async {
        var headers = await getServerRequestHeaders(
          server: server,
          headers: {},
        );

        expect(headers.via_.valueOrNullIfInvalid, isNull);
        expect(() => headers.via, throwsA(isA<InvalidHeaderException>()));
      },
    );
  });

  group('Given a Via header with the strict flag false', () {
    late RelicServer server;

    setUp(() async {
      server = await createServer(strictHeaders: false);
    });

    tearDown(() => server.close());

    group('when an empty Via header is passed', () {
      test(
        'then it should return null',
        () async {
          var headers = await getServerRequestHeaders(
            server: server,
            headers: {'via': ''},
          );

          expect(headers.via_.valueOrNullIfInvalid, isNull);
          expect(() => headers.via, throwsA(isA<InvalidHeaderException>()));
        },
      );
    });
  });
}
