import 'package:relic/relic.dart';
import 'package:test/test.dart';

import '../docs/strict_validation_docs.dart';
import '../headers_test_utils.dart';

/// Reference: https://developer.mozilla.org/en-US/docs/Web/HTTP/Headers/Content-Disposition
/// For more details on header validation behavior, see the [HeaderValidationDocs] class.
void main() {
  group('Given a Content-Disposition header with validation', () {
    late RelicServer server;

    setUp(() async {
      server = await createServer();
    });

    tearDown(() => server.close());

    test(
      'when an empty Content-Disposition header is passed then the server should respond with a bad request '
      'including a message that states the value cannot be empty',
      () async {
        expect(
          getServerRequestHeaders(
            server: server,
            touchHeaders: (final h) => h.contentDisposition,
            headers: {'content-disposition': ''},
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

    test('when a Content-Disposition header with an empty value is passed '
        'then the server does not respond with a bad request if the headers '
        'is not actually used', () async {
      final headers = await getServerRequestHeaders(
        server: server,
        touchHeaders: (_) {},
        headers: {'content-disposition': ''},
      );

      expect(headers, isNotNull);
    });

    test(
      'when a Content-Disposition header is passed then it should parse correctly',
      () async {
        final headers = await getServerRequestHeaders(
          server: server,
          touchHeaders: (_) {},
          headers: {
            'content-disposition': 'attachment; filename="example.txt"',
          },
        );

        expect(headers.contentDisposition?.type, equals('attachment'));
        expect(
          headers.contentDisposition?.parameters.first.name,
          equals('filename'),
        );
        expect(
          headers.contentDisposition?.parameters.first.value,
          equals('example.txt'),
        );
      },
    );

    test(
      'when a Content-Disposition header with "inline" type is passed then it should parse correctly',
      () async {
        final headers = await getServerRequestHeaders(
          server: server,
          touchHeaders: (final h) => h.contentDisposition,
          headers: {'content-disposition': 'inline'},
        );

        expect(headers.contentDisposition?.type, equals('inline'));
        expect(headers.contentDisposition?.parameters.isEmpty, isTrue);
      },
    );

    test(
      'when a Content-Disposition header with multiple parameters is passed then it should parse correctly',
      () async {
        final headers = await getServerRequestHeaders(
          server: server,
          touchHeaders: (_) {},
          headers: {
            'content-disposition':
                'attachment; filename="example.txt"; size=12345',
          },
        );

        expect(headers.contentDisposition?.type, equals('attachment'));
        expect(
          headers.contentDisposition?.parameters.first.name,
          equals('filename'),
        );
        expect(
          headers.contentDisposition?.parameters.first.value,
          equals('example.txt'),
        );
        expect(
          headers.contentDisposition?.parameters.last.name,
          equals('size'),
        );
        expect(
          headers.contentDisposition?.parameters.last.value,
          equals('12345'),
        );
      },
    );

    test(
      'when no Content-Disposition header is passed then it should return null',
      () async {
        final headers = await getServerRequestHeaders(
          server: server,
          touchHeaders: (final h) => h.contentDisposition,
          headers: {},
        );

        expect(headers.contentDisposition, isNull);
      },
    );
  });

  group('Given a Content-Disposition header without validation', () {
    late RelicServer server;

    setUp(() async {
      server = await createServer();
    });

    tearDown(() => server.close());

    group('when an empty Content-Disposition header is passed', () {
      test('then it should return null', () async {
        final headers = await getServerRequestHeaders(
          server: server,
          touchHeaders: (_) {},
          headers: {'content-disposition': ''},
        );

        expect(
          Headers.contentDisposition[headers].valueOrNullIfInvalid,
          isNull,
        );
        expect(() => headers.contentDisposition, throwsInvalidHeader);
      });
    });
  });
}
