import 'package:relic/relic.dart';
import 'package:test/test.dart';

import '../docs/strict_validation_docs.dart';
import '../headers_test_utils.dart';

/// Reference: https://developer.mozilla.org/en-US/docs/Web/HTTP/Headers/Via
/// For more details on header validation behavior, see the [HeaderValidationDocs] class.
void main() {
  group('Given a Via header with validation', () {
    late RelicServer server;

    setUp(() async {
      server = await createServer();
    });

    tearDown(() => server.close());

    test('when an empty Via header is passed then the server responds '
        'with a bad request including a message that states the header value '
        'cannot be empty', () async {
      expect(
        getServerRequestHeaders(
          server: server,
          headers: {'via': ''},
          touchHeaders: (final h) => h.via,
        ),
        throwsA(
          isA<BadRequestException>().having(
            (final e) => e.message,
            'message',
            contains('Value cannot be empty'),
          ),
        ),
      );
    });

    test('when a Via header with an empty value is passed '
        'then the server does not respond with a bad request if the headers '
        'is not actually used', () async {
      final headers = await getServerRequestHeaders(
        server: server,
        touchHeaders: (_) {},
        headers: {'via': ''},
      );

      expect(headers, isNotNull);
    });

    test(
      'when a valid Via header is passed then it should parse the values correctly',
      () async {
        final headers = await getServerRequestHeaders(
          server: server,
          headers: {'via': '1.1 example.com, 1.0 another.com'},
          touchHeaders: (final h) => h.via,
        );

        expect(headers.via, equals(['1.1 example.com', '1.0 another.com']));
      },
    );

    test(
      'when a Via header with extra whitespace is passed then it should parse the values correctly',
      () async {
        final headers = await getServerRequestHeaders(
          server: server,
          headers: {'via': ' 1.1 example.com , 1.0 another.com '},
          touchHeaders: (final h) => h.via,
        );

        expect(headers.via, equals(['1.1 example.com', '1.0 another.com']));
      },
    );

    test(
      'when a Via header with duplicate values is passed then it should parse '
      'the values correctly and remove duplicates',
      () async {
        final headers = await getServerRequestHeaders(
          server: server,
          headers: {'via': '1.1 example.com, 1.0 another.com, 1.0 another.com'},
          touchHeaders: (final h) => h.via,
        );

        expect(headers.via, equals(['1.1 example.com', '1.0 another.com']));
      },
    );

    test('when no Via header is passed then it should return null', () async {
      final headers = await getServerRequestHeaders(
        server: server,
        headers: {},
        touchHeaders: (final h) => h.via,
      );

      expect(headers.via, isNull);
    });
  });

  group('Given a Via header without validation', () {
    late RelicServer server;

    setUp(() async {
      server = await createServer();
    });

    tearDown(() => server.close());

    group('when an empty Via header is passed', () {
      test('then it should return null', () async {
        final headers = await getServerRequestHeaders(
          server: server,
          touchHeaders: (_) {},
          headers: {'via': ''},
        );

        expect(Headers.via[headers].valueOrNullIfInvalid, isNull);
        expect(() => headers.via, throwsInvalidHeader);
      });
    });
  });
}
