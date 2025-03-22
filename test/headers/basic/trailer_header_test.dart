import 'package:relic/relic.dart';
import 'package:relic/src/headers/standard_headers_extensions.dart';
import 'package:test/test.dart';

import '../docs/strict_validation_docs.dart';
import '../headers_test_utils.dart';

/// Reference: https://developer.mozilla.org/en-US/docs/Web/HTTP/Headers/Trailer
/// About empty value test, check the [StrictValidationDocs] class for more details.
void main() {
  group('Given a Trailer header with the strict flag true',
      skip: 'drop strict mode', () {
    late RelicServer server;

    setUp(() async {
      server = await createServer(strictHeaders: true);
    });

    tearDown(() => server.close());

    test(
      'when an empty Trailer header is passed then the server should respond with a bad request '
      'including a message that states the value cannot be empty',
      () async {
        expect(
          () async => await getServerRequestHeaders(
            server: server,
            headers: {'trailer': ''},
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
      'when a Trailer header with an empty value is passed '
      'then the server does not respond with a bad request if the headers '
      'is not actually used',
      () async {
        var headers = await getServerRequestHeaders(
          server: server,
          headers: {'trailer': ''},
          eagerParseHeaders: false,
        );

        expect(headers, isNotNull);
      },
    );

    test(
      'when a valid Trailer header is passed then it should parse correctly',
      () async {
        var headers = await getServerRequestHeaders(
          server: server,
          headers: {'trailer': 'Expires, Content-MD5, Content-Language'},
        );

        expect(
          headers.trailer,
          equals(['Expires', 'Content-MD5', 'Content-Language']),
        );
      },
    );

    test(
      'when a Trailer header with whitespace is passed then it should parse correctly',
      () async {
        var headers = await getServerRequestHeaders(
          server: server,
          headers: {'trailer': ' Expires , Content-MD5 , Content-Language '},
        );

        expect(
          headers.trailer,
          equals(['Expires', 'Content-MD5', 'Content-Language']),
        );
      },
    );

    test(
      'when a Trailer header with custom values is passed then it should parse correctly',
      () async {
        var headers = await getServerRequestHeaders(
          server: server,
          headers: {'trailer': 'custom-header, AnotherHeader'},
        );

        expect(
          headers.trailer,
          equals(['custom-header', 'AnotherHeader']),
        );
      },
    );

    test(
      'when no Trailer header is passed then it should return null',
      () async {
        var headers = await getServerRequestHeaders(
          server: server,
          headers: {},
        );

        expect(headers.trailer_.valueOrNullIfInvalid, isNull);
        expect(() => headers.trailer, throwsA(isA<InvalidHeaderException>()));
      },
    );
  });

  group('Given a Trailer header with the strict flag false', () {
    late RelicServer server;

    setUp(() async {
      server = await createServer(strictHeaders: false);
    });

    tearDown(() => server.close());

    test(
      'when a custom Trailer header is passed then it should parse correctly',
      () async {
        var headers = await getServerRequestHeaders(
          server: server,
          headers: {'trailer': 'custom-header'},
        );

        expect(headers.trailer, equals(['custom-header']));
      },
    );

    test(
      'when an empty Trailer header is passed then it should be recorded in failedHeadersToParse',
      skip: 'todo: drop failedHeadersToParse',
      () async {
        var headers = await getServerRequestHeaders(
          server: server,
          headers: {'trailer': ''},
        );

        expect(
          headers.failedHeadersToParse['trailer'],
          equals(['']),
        );
      },
    );
  });
}
