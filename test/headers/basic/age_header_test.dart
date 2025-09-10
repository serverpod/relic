import 'package:relic/relic.dart';
import 'package:test/test.dart';

import '../docs/strict_validation_docs.dart';
import '../headers_test_utils.dart';

/// Reference: https://developer.mozilla.org/en-US/docs/Web/HTTP/Headers/Age
/// About empty value test, check the [StrictValidationDocs] class for more details.
void main() {
  group(
    'Given an Age header with the strict flag true',
    () {
      late RelicServer server;

      setUp(() async {
        server = await createServer();
      });

      tearDown(() => server.close());

      test(
        'when an empty Age header is passed then the server responds with a bad '
        'request including a message that states the header value cannot be empty',
        () async {
          expect(
            getServerRequestHeaders(
              server: server,
              headers: {'age': ''},
              touchHeaders: (final h) => h.age,
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
        'when an invalid Age header is passed then the server responds with a bad '
        'request including a message that states the age is invalid',
        () async {
          expect(
            getServerRequestHeaders(
              server: server,
              headers: {'age': 'invalid'},
              touchHeaders: (final h) => h.age,
            ),
            throwsA(
              isA<BadRequestException>().having(
                (final e) => e.message,
                'message',
                contains('Invalid number'),
              ),
            ),
          );
        },
      );

      test(
        'when an negative Age header is passed then the server responds with a bad '
        'request including a message that states the age must be non-negative',
        () async {
          expect(
            getServerRequestHeaders(
              server: server,
              headers: {'age': '-3600'},
              touchHeaders: (final h) => h.age,
            ),
            throwsA(
              isA<BadRequestException>().having(
                (final e) => e.message,
                'message',
                contains('Must be non-negative'),
              ),
            ),
          );
        },
      );

      test(
        'when an non-integer Age header is passed then the server responds with a '
        'bad request including a message that states the age must be an integer',
        () async {
          expect(
            getServerRequestHeaders(
              server: server,
              headers: {'age': '3.14'},
              touchHeaders: (final h) => h.age,
            ),
            throwsA(
              isA<BadRequestException>().having(
                (final e) => e.message,
                'message',
                contains('Must be an integer'),
              ),
            ),
          );
        },
      );

      test(
        'when an Age header with an invalid value is passed '
        'then the server does not respond with a bad request if the headers '
        'is not actually used',
        () async {
          final headers = await getServerRequestHeaders(
            server: server,
            touchHeaders: (final _) {},
            headers: {'age': 'invalid-age-format'},
          );

          expect(headers, isNotNull);
        },
      );

      test(
        'when a valid Age header is passed then it should parse the age correctly',
        () async {
          final headers = await getServerRequestHeaders(
            server: server,
            headers: {'age': '3600'},
            touchHeaders: (final h) => h.age,
          );

          expect(headers.age, equals(3600));
        },
      );

      test(
        'when an Age header with extra whitespace is passed then it should parse '
        'the age correctly',
        () async {
          final headers = await getServerRequestHeaders(
            server: server,
            headers: {'age': ' 3600 '},
            touchHeaders: (final h) => h.age,
          );

          expect(headers.age, equals(3600));
        },
      );

      test(
        'when no Age header is passed then it should return null',
        () async {
          final headers = await getServerRequestHeaders(
            server: server,
            headers: {},
            touchHeaders: (final h) => h.age,
          );

          expect(headers.age, isNull);
        },
      );
    },
  );

  group('Given an Age header with the strict flag false', () {
    late RelicServer server;

    setUp(() async {
      server = await createServer();
    });

    tearDown(() => server.close());

    group('when an empty Age header is passed', () {
      test(
        'then it should return null',
        () async {
          final headers = await getServerRequestHeaders(
            server: server,
            touchHeaders: (final _) {},
            headers: {'age': ''},
          );

          expect(Headers.age[headers].valueOrNullIfInvalid, isNull);
          expect(() => headers.age, throwsInvalidHeader);
        },
      );
    });

    group('when an invalid Age header is passed', () {
      test(
        'then it should return null',
        () async {
          final headers = await getServerRequestHeaders(
            server: server,
            touchHeaders: (final _) {},
            headers: {'age': 'invalid'},
          );

          expect(Headers.age[headers].valueOrNullIfInvalid, isNull);
          expect(() => headers.age, throwsInvalidHeader);
        },
      );
    });
  });
}
