import 'package:relic/relic.dart';
import 'package:relic/src/headers/standard_headers_extensions.dart';
import 'package:test/test.dart';

import '../docs/strict_validation_docs.dart';
import '../headers_test_utils.dart';

/// Reference: https://developer.mozilla.org/en-US/docs/Web/HTTP/Headers/Accept-Ranges
/// About empty value test, check the [StrictValidationDocs] class for more details.
void main() {
  group('Given an Accept-Ranges header with the strict flag true',
      skip: 'todo: drop strict mode', () {
    late RelicServer server;

    setUp(() async {
      server = await createServer(strictHeaders: true);
    });

    tearDown(() => server.close());

    test(
      'when an empty Accept-Ranges header is passed then the server should respond with a bad request '
      'including a message that states the value cannot be empty',
      () async {
        expect(
          () async => await getServerRequestHeaders(
            server: server,
            headers: {'accept-ranges': ''},
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
      'when an Accept-Ranges header with an empty value is passed '
      'then the server does not respond with a bad request if the headers '
      'is not actually used',
      () async {
        var headers = await getServerRequestHeaders(
          server: server,
          headers: {'accept-ranges': ''},
          eagerParseHeaders: false,
        );

        expect(headers, isNotNull);
      },
    );

    test(
      'when a valid Accept-Ranges header is passed then it should parse the range unit correctly',
      () async {
        var headers = await getServerRequestHeaders(
          server: server,
          headers: {'accept-ranges': 'bytes'},
        );

        expect(headers.acceptRanges?.rangeUnit, equals('bytes'));
        expect(headers.acceptRanges?.isBytes, isTrue);
      },
    );

    test(
      'when a Accept-Ranges header with "none" is passed then it should parse correctly',
      () async {
        var headers = await getServerRequestHeaders(
          server: server,
          headers: {'accept-ranges': 'none'},
        );

        expect(headers.acceptRanges?.rangeUnit, equals('none'));
        expect(headers.acceptRanges?.isNone, isTrue);
      },
    );

    test(
      'when no Accept-Ranges header is passed then it should return null',
      () async {
        var headers = await getServerRequestHeaders(
          server: server,
          headers: {},
        );

        expect(headers.acceptRanges_.valueOrNullIfInvalid, isNull);
        expect(
            () => headers.acceptRanges, throwsA(isA<InvalidHeaderException>()));
      },
    );
  });

  group('Given an Accept-Ranges header with the strict flag false', () {
    late RelicServer server;

    setUp(() async {
      server = await createServer(strictHeaders: false);
    });

    tearDown(() => server.close());

    group('when an empty Accept-Ranges header is passed', () {
      test(
        'then it should return null',
        () async {
          var headers = await getServerRequestHeaders(
            server: server,
            headers: {'accept-ranges': ''},
          );

          expect(headers.acceptRanges_.valueOrNullIfInvalid, isNull);
          expect(() => headers.acceptRanges,
              throwsA(isA<InvalidHeaderException>()));
        },
      );
    });
  });
}
