import 'package:relic/relic.dart';
import 'package:test/test.dart';

import '../docs/strict_validation_docs.dart';
import '../headers_test_utils.dart';

/// Reference: https://developer.mozilla.org/en-US/docs/Web/HTTP/Headers/From
/// For more details on header validation behavior, see the [HeaderValidationDocs] class.
void main() {
  group('Given a From header with validation', () {
    late RelicServer server;

    setUp(() async {
      server = await createServer();
    });

    tearDown(() => server.close());

    test(
      'when an empty From header is passed then the server responds '
      'with a bad request including a message that states the header value '
      'cannot be empty',
      () async {
        expect(
          getServerRequestHeaders(
            server: server,
            touchHeaders: (final h) => h.from,
            headers: {'from': ''},
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
      'when a From header with an invalid email format is passed '
      'then the server responds with a bad request including a message that '
      'states the email format is invalid',
      () async {
        expect(
          getServerRequestHeaders(
            server: server,
            touchHeaders: (final h) => h.from,
            headers: {'from': 'invalid-email-format'},
          ),
          throwsA(
            isA<BadRequestException>().having(
              (final e) => e.message,
              'message',
              contains('Invalid email format'),
            ),
          ),
        );
      },
    );

    test(
      'when a From header with an invalid value is passed '
      'then the server does not respond with a bad request if the headers '
      'is not actually used',
      () async {
        final headers = await getServerRequestHeaders(
          server: server,
          touchHeaders: (final _) {},
          headers: {'from': 'invalid-email-format'},
        );

        expect(headers, isNotNull);
      },
    );

    test(
      'when a valid From header is passed then it should parse the email correctly',
      () async {
        final headers = await getServerRequestHeaders(
          server: server,
          touchHeaders: (final h) => h.from,
          headers: {'from': 'user@example.com'},
        );

        expect(headers.from?.emails, equals(['user@example.com']));
      },
    );

    test(
      'when a From header with extra whitespace is passed then it should parse the email correctly',
      () async {
        final headers = await getServerRequestHeaders(
          server: server,
          touchHeaders: (final h) => h.from,
          headers: {'from': ' user@example.com '},
        );

        expect(headers.from?.emails, equals(['user@example.com']));
      },
    );

    group('when multiple', () {
      test(
        'From headers are passed then they should parse all emails correctly',
        () async {
          final headers = await getServerRequestHeaders(
            server: server,
            touchHeaders: (final h) => h.from,
            headers: {'from': 'user1@example.com, user2@example.com'},
          );

          expect(
            headers.from?.emails,
            equals(['user1@example.com', 'user2@example.com']),
          );
        },
      );

      test(
        'From headers with extra whitespace are passed then they should parse all emails correctly',
        () async {
          final headers = await getServerRequestHeaders(
            server: server,
            touchHeaders: (final h) => h.from,
            headers: {'from': ' user1@example.com , user2@example.com '},
          );

          expect(
            headers.from?.emails,
            equals(['user1@example.com', 'user2@example.com']),
          );
        },
      );

      test(
        'From headers with extra duplicate values are passed then they should '
        'parse all emails correctly and remove duplicates',
        () async {
          final headers = await getServerRequestHeaders(
            server: server,
            touchHeaders: (final h) => h.from,
            headers: {
              'from': 'user1@example.com, user2@example.com, user1@example.com'
            },
          );

          expect(
            headers.from?.emails,
            equals(['user1@example.com', 'user2@example.com']),
          );
        },
      );

      test(
        'From headers with an invalid email format among valid ones are passed '
        'then the server responds with a bad request including a message that '
        'states the email format is invalid',
        () async {
          expect(
            getServerRequestHeaders(
              server: server,
              touchHeaders: (final h) => h.from,
              headers: {
                'from':
                    'user1@example.com, invalid-email-format, user2@example.com'
              },
            ),
            throwsA(
              isA<BadRequestException>().having(
                (final e) => e.message,
                'message',
                contains('Invalid email format'),
              ),
            ),
          );
        },
      );
    });

    test(
      'when no From header is passed then it should return null',
      () async {
        final headers = await getServerRequestHeaders(
          server: server,
          touchHeaders: (final h) => h.from,
          headers: {},
        );

        expect(headers.from, isNull);
      },
    );
  });

  group('Given a From header without validation', () {
    late RelicServer server;

    setUp(() async {
      server = await createServer();
    });

    tearDown(() => server.close());

    group('when an invalid From header is passed', () {
      test(
        'then it should return null',
        () async {
          final headers = await getServerRequestHeaders(
            server: server,
            touchHeaders: (final _) {},
            headers: {'from': 'invalid-email-format'},
          );

          expect(Headers.from[headers].valueOrNullIfInvalid, isNull);
          expect(() => headers.from, throwsInvalidHeader);
        },
      );
    });
  });
}
