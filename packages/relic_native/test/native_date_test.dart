import 'package:http_parser/http_parser.dart' as parser;
import 'package:relic_core/relic_core.dart';
import 'package:test/test.dart';
import 'package:test_utils/adapter_conformance.dart';

import 'native_test_helpers.dart';

/// The three ways a response leaves: in the connection's own buffer, as a
/// head and a body the native side takes over, and as a stream.
Response _handler(Request req) => switch (req.url.path) {
  '/inline' => Response.ok(body: Body.fromString('ok')),
  '/large' => Response.ok(body: Body.fromString('x' * (64 * 1024))),
  '/stream' => Response.ok(
    body: Body.fromDataStream(
      Stream.fromIterable([Body.fromString('ok').bytes!]),
    ),
  ),
  _ => Response.notFound(),
};

void main() {
  late RelicServer server;
  setUp(() async => server = await serveNative(_handler));
  tearDown(() => server.close(force: true));

  for (final path in ['/inline', '/large', '/stream']) {
    test('Given a response on $path, '
        'when it is read, '
        'then its Date is the time it was sent', () async {
      final before = DateTime.now().toUtc();
      final reply = await rawExchange(
        server.port,
        'GET $path HTTP/1.1\r\nHost: x\r\nConnection: close\r\n\r\n',
      );
      final line = RegExp(
        r'\r\ndate: ([^\r]+)\r\n',
      ).firstMatch(reply.split('\r\n\r\n').first);
      expect(line, isNotNull, reason: reply);
      final date = parser.parseHttpDate(line!.group(1)!);
      expect(date.difference(before).inSeconds.abs(), lessThanOrEqualTo(2));
    });
  }
}
