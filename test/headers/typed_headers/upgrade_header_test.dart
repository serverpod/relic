import 'package:relic/relic.dart';
import 'package:relic/src/headers/standard_headers_extensions.dart';
import 'package:test/test.dart';

import '../docs/strict_validation_docs.dart';
import '../headers_test_utils.dart';

/// Reference: https://developer.mozilla.org/en-US/docs/Web/HTTP/Headers/Upgrade
/// About empty value test, check the [StrictValidationDocs] class for more details.
void main() {
  group('Given an Upgrade header with the strict flag true', () {
    late RelicServer server;

    setUp(() async {
      server = await createServer(strictHeaders: true);
    });

    tearDown(() => server.close());

    test(
      'when an empty Upgrade header is passed then the server should respond with a bad request '
      'including a message that states the value cannot be empty',
      () async {
        expect(
          getServerRequestHeaders(
            server: server,
            touchHeaders: (final h) => h.upgrade,
            headers: {'upgrade': ''},
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
      'when an Upgrade header with an invalid protocol version is passed then '
      'the server should respond with a bad request including a message that '
      'states the version is invalid',
      () async {
        expect(
          getServerRequestHeaders(
            server: server,
            touchHeaders: (final h) => h.upgrade,
            headers: {'upgrade': 'InvalidProtocol/abc'},
          ),
          throwsA(isA<BadRequestException>().having(
            (final e) => e.message,
            'message',
            contains('Invalid version'),
          )),
        );
      },
    );

    test(
      'when a Upgrade header with an invalid protocol is passed '
      'then the server does not respond with a bad request if the headers '
      'is not actually used',
      () async {
        final headers = await getServerRequestHeaders(
          server: server,
          touchHeaders: (final _) {},
          headers: {'upgrade': 'InvalidProtocol/abc'},
        );

        expect(headers, isNotNull);
      },
    );

    test(
      'when no Upgrade header is passed then it should return null',
      () async {
        final headers = await getServerRequestHeaders(
          server: server,
          touchHeaders: (final _) {},
          headers: {},
        );

        expect(headers.upgrade, isNull);
      },
    );

    group('when multiple Upgrade protocols are passed', () {
      test(
        'with invalid protocols versions then the server should respond with a '
        'bad request including a message that states the version is invalid',
        () async {
          expect(
            getServerRequestHeaders(
              server: server,
              touchHeaders: (final h) => h.upgrade,
              headers: {'upgrade': 'HTTP/2.0, HTTP/abc'},
            ),
            throwsA(isA<BadRequestException>().having(
              (final e) => e.message,
              'message',
              contains('Invalid version'),
            )),
          );
        },
      );

      test(
        'then it should parse the protocols correctly',
        () async {
          final headers = await getServerRequestHeaders(
            server: server,
            touchHeaders: (final h) => h.upgrade,
            headers: {'upgrade': 'HTTP/2.0, WebSocket'},
          );

          final protocols = headers.upgrade?.protocols;
          expect(protocols?.length, equals(2));
          expect(protocols?[0].protocol, equals('HTTP'));
          expect(protocols?[0].version, equals(2));
          expect(protocols?[1].protocol, equals('WebSocket'));
          expect(protocols?[1].version, isNull);
        },
      );

      test(
        'with duplicate protocols then it should parse the protocols correctly '
        'and remove the duplicates',
        () async {
          final headers = await getServerRequestHeaders(
            server: server,
            touchHeaders: (final h) => h.upgrade,
            headers: {'upgrade': 'HTTP/2.0, WebSocket, HTTP/2.0'},
          );

          final protocols = headers.upgrade?.protocols;
          expect(protocols?.length, equals(2));
        },
      );
    });
  });
}
