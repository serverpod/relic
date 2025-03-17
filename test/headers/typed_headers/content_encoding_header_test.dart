import 'package:test/test.dart';
import 'package:relic/src/headers/standard_headers_extensions.dart';
import 'package:relic/src/relic_server.dart';

import '../headers_test_utils.dart';
import '../docs/strict_validation_docs.dart';

/// Reference: https://developer.mozilla.org/en-US/docs/Web/HTTP/Headers/Content-Encoding
/// About empty value test, check the [StrictValidationDocs] class for more details.
void main() {
  group('Given a Content-Encoding header with the strict flag true', () {
    late RelicServer server;

    setUp(() async {
      server = await createServer(strictHeaders: true);
    });

    tearDown(() => server.close());

    test(
      'when an empty Content-Encoding header is passed then the server responds '
      'with a bad request including a message that states the header value '
      'cannot be empty',
      () async {
        expect(
          () async => await getServerRequestHeaders(
            server: server,
            headers: {'content-encoding': ''},
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
      'when an invalid Content-Encoding header is passed then the server responds '
      'with a bad request including a message that states the header value '
      'is invalid',
      () async {
        expect(
          () async => await getServerRequestHeaders(
            server: server,
            headers: {'content-encoding': 'custom-encoding'},
          ),
          throwsA(
            isA<BadRequestException>().having(
              (e) => e.message,
              'message',
              contains('Invalid value'),
            ),
          ),
        );
      },
    );

    test(
      'when a Content-Encoding header with an invalid value is passed '
      'then the server does not respond with a bad request if the headers '
      'is not actually used',
      () async {
        var headers = await getServerRequestHeaders(
          server: server,
          headers: {'content-encoding': 'custom-encoding'},
          eagerParseHeaders: false,
        );

        expect(headers, isNotNull);
      },
    );

    test(
      'when a single valid encoding is passed then it should parse correctly',
      () async {
        var headers = await getServerRequestHeaders(
          server: server,
          headers: {'content-encoding': 'gzip'},
        );

        expect(
          headers.contentEncoding?.encodings.map((e) => e.name).toList(),
          equals(['gzip']),
        );
      },
    );

    test(
      'when no Content-Encoding header is passed then it should return null',
      () async {
        var headers = await getServerRequestHeaders(
          server: server,
          headers: {},
        );

        expect(headers.contentEncoding, isNull);
      },
    );

    group('when multiple Content-Encoding encodings are passed', () {
      test(
        'then they should parse correctly',
        () async {
          var headers = await getServerRequestHeaders(
            server: server,
            headers: {'content-encoding': 'gzip, deflate'},
          );

          expect(
            headers.contentEncoding?.encodings.map((e) => e.name).toList(),
            equals(['gzip', 'deflate']),
          );
        },
      );

      test(
        'with extra whitespace should parse correctly',
        () async {
          var headers = await getServerRequestHeaders(
            server: server,
            headers: {'content-encoding': ' gzip , deflate '},
          );

          expect(
            headers.contentEncoding?.encodings.map((e) => e.name).toList(),
            equals(['gzip', 'deflate']),
          );
        },
      );

      test(
        'with duplicate encodings should parse correctly and remove duplicates',
        () async {
          var headers = await getServerRequestHeaders(
            server: server,
            headers: {'content-encoding': 'gzip, deflate, gzip'},
          );

          expect(
            headers.contentEncoding?.encodings.map((e) => e.name).toList(),
            equals(['gzip', 'deflate']),
          );
        },
      );
    });
  });

  group('Given a Content-Encoding header with the strict flag false', () {
    late RelicServer server;

    setUp(() async {
      server = await createServer(strictHeaders: false);
    });

    tearDown(() => server.close());

    group('when an invalid Content-Encoding header is passed', () {
      test(
        'then it should return null',
        () async {
          var headers = await getServerRequestHeaders(
            server: server,
            headers: {'content-encoding': ''},
          );

          expect(headers.contentEncoding, isNull);
        },
      );

      test(
        'then it should be recorded in the "failedHeadersToParse" field',
        () async {
          var headers = await getServerRequestHeaders(
            server: server,
            headers: {'content-encoding': ''},
          );

          expect(
            headers.failedHeadersToParse['content-encoding'],
            equals(['']),
          );
        },
      );
    });
  });
}
