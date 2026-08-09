import 'dart:io' as io;

import 'package:relic_core/relic_core.dart';
import 'package:test/test.dart';

import '../util/test_util.dart';

void main() {
  late RelicServer server;

  tearDown(() => server.close());

  Future<String> rawResponse() async {
    final socket = await io.Socket.connect('127.0.0.1', server.url.port);
    socket.write('GET / HTTP/1.1\r\nHost: x\r\nConnection: close\r\n\r\n');
    final bytes = await socket
        .fold<List<int>>([], (final a, final b) => a..addAll(b))
        .timeout(const Duration(seconds: 5), onTimeout: () => const []);
    return String.fromCharCodes(bytes);
  }

  group('Given a body whose MIME type carries a line break', () {
    setUp(() async {
      server = await testServe(
        (final req) async => Response.ok(
          body: Body.fromString(
            'x',
            mimeType: const MimeType('text', 'plain\r\nX-Injected: 1'),
          ),
        ),
      );
    });

    test('when the response is written, '
        'then no header is injected into it.', () async {
      final response = await rawResponse();

      expect(
        response.toLowerCase(),
        isNot(contains('x-injected')),
        reason: 'The MIME type must not be able to add a header',
      );
    });

    test('when the response is written, '
        'then the header block is not terminated early.', () async {
      final response = await rawResponse();

      expect(
        response,
        isNot(contains('INJECTED')),
        reason: 'The MIME type must not be able to start the body',
      );
      expect(response, startsWith('HTTP/1.1 500'));
    });
  });
}
