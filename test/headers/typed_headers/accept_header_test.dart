import 'package:relic/relic.dart';
import 'package:relic/src/headers/standard_headers_extensions.dart';
import 'package:test/test.dart';

import '../docs/strict_validation_docs.dart';
import '../headers_test_utils.dart';

/// Reference: https://developer.mozilla.org/en-US/docs/Web/HTTP/Headers/Accept
/// About empty value test, check the [StrictValidationDocs] class for more details.
void main() {
  group('Given an Accept header with the strict flag true', () {
    late RelicServer server;

    setUp(() async {
      server = await createServer(strictHeaders: true);
    });

    tearDown(() => server.close());

    test(
      'when an empty Accept header is passed then the server should respond with a bad request '
      'including a message that states the value cannot be empty',
      () async {
        expect(
          getServerRequestHeaders(
            server: server,
            touchHeaders: (final h) => h.accept,
            headers: {'accept': ''},
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
      'when an Accept header with invalid quality value is passed then the server '
      'should respond with a bad request including a message that states the '
      'quality value is invalid',
      () async {
        expect(
          getServerRequestHeaders(
            server: server,
            touchHeaders: (final h) => h.accept,
            headers: {'accept': 'text/html;q=abc'},
          ),
          throwsA(isA<BadRequestException>().having(
            (final e) => e.message,
            'message',
            contains('Invalid quality value'),
          )),
        );
      },
    );

    test(
      'when an Accept header with an invalid value is passed '
      'then the server does not respond with a bad request if the headers '
      'is not actually used',
      () async {
        final headers = await getServerRequestHeaders(
          server: server,
          touchHeaders: (final _) {},
          headers: {'accept': 'text/html;q=abc'},
        );

        expect(headers, isNotNull);
      },
    );

    test(
      'when a valid Accept header is passed then it should parse the media types correctly',
      () async {
        final headers = await getServerRequestHeaders(
          server: server,
          touchHeaders: (final h) => h.accept,
          headers: {'accept': 'text/html'},
        );

        final mediaRanges = headers.accept?.mediaRanges;
        expect(mediaRanges?.length, equals(1));
        expect(mediaRanges?[0].type, equals('text'));
        expect(mediaRanges?[0].subtype, equals('html'));
      },
    );

    test(
      'when a valid Accept header with no quality value is passed then the '
      'quality value should set to default of 1.0',
      () async {
        final headers = await getServerRequestHeaders(
          server: server,
          touchHeaders: (final h) => h.accept,
          headers: {'accept': 'text/html'},
        );

        final mediaRanges = headers.accept?.mediaRanges;
        expect(mediaRanges?.length, equals(1));
        expect(mediaRanges?[0].quality, equals(1.0));
      },
    );

    test(
      'when a valid Accept header with quality value is passed then it should parse the quality value correctly',
      () async {
        final headers = await getServerRequestHeaders(
          server: server,
          touchHeaders: (final h) => h.accept,
          headers: {'accept': 'text/html;q=0.8'},
        );

        final mediaRanges = headers.accept?.mediaRanges;
        expect(mediaRanges?.length, equals(1));
        expect(mediaRanges?[0].quality, equals(0.8));
      },
    );

    test(
      'when an Accept header with wildcard (*) is passed then it should parse the wildcard correctly',
      () async {
        final headers = await getServerRequestHeaders(
          server: server,
          touchHeaders: (final h) => h.accept,
          headers: {'accept': '*/*'},
        );

        final mediaRanges = headers.accept?.mediaRanges;
        expect(mediaRanges?.length, equals(1));
        expect(mediaRanges?[0].type, equals('*'));
        expect(mediaRanges?[0].subtype, equals('*'));
      },
    );

    test(
      'when no Accept header is passed then it should return null',
      () async {
        final headers = await getServerRequestHeaders(
          server: server,
          touchHeaders: (final h) => h.accept,
          headers: {},
        );

        expect(headers.accept, isNull);
      },
    );

    group('when multiple Accept media ranges are passed', () {
      test(
        'with invalid quality values are passed then the server should respond with a bad request '
        'including a message that states the quality value is invalid',
        () async {
          expect(
            getServerRequestHeaders(
              server: server,
              touchHeaders: (final h) => h.accept,
              headers: {
                'accept': 'text/html;q=test, application/json;q=abc, */*;q=0.5'
              },
            ),
            throwsA(isA<BadRequestException>().having(
              (final e) => e.message,
              'message',
              contains('Invalid quality value'),
            )),
          );
        },
      );
      test(
        'with different quality values are passed then they should parse correctly',
        () async {
          final headers = await getServerRequestHeaders(
            server: server,
            touchHeaders: (final h) => h.accept,
            headers: {
              'accept': 'text/html;q=0.8, application/json;q=0.9, */*;q=0.5'
            },
          );

          final mediaRanges = headers.accept?.mediaRanges;
          expect(mediaRanges?.length, equals(3));
          expect(mediaRanges?[0].type, equals('text'));
          expect(mediaRanges?[0].subtype, equals('html'));
          expect(mediaRanges?[1].type, equals('application'));
          expect(mediaRanges?[1].subtype, equals('json'));
          expect(mediaRanges?[2].type, equals('*'));
          expect(mediaRanges?[2].subtype, equals('*'));
        },
      );

      test(
        'with different quality values are passed then it should parse the quality values correctly',
        () async {
          final headers = await getServerRequestHeaders(
            server: server,
            touchHeaders: (final h) => h.accept,
            headers: {
              'accept': 'text/html;q=0.8, application/json;q=0.9, */*;q=0.5'
            },
          );

          final mediaRanges = headers.accept?.mediaRanges;
          expect(mediaRanges?.length, equals(3));
          expect(mediaRanges?[0].quality, equals(0.8));
          expect(mediaRanges?[1].quality, equals(0.9));
          expect(mediaRanges?[2].quality, equals(0.5));
        },
      );
    });
  });

  group('Given an Accept header with the strict flag false', () {
    late RelicServer server;

    setUp(() async {
      server = await createServer(strictHeaders: false);
    });

    tearDown(() => server.close());

    group('when an Accept header with invalid quality value is passed', () {
      test(
        'then it should return null',
        () async {
          final headers = await getServerRequestHeaders(
            server: server,
            touchHeaders: (final _) {},
            headers: {'accept': 'text/html;q=abc'},
          );

          expect(Headers.accept[headers].valueOrNullIfInvalid, isNull);
          expect(() => headers.accept, throwsInvalidHeader);
        },
      );
    });
  });
}
