import 'package:relic_core/relic_core.dart';
import 'package:test/test.dart';
import 'package:test_utils/adapter_conformance.dart';

import '../util/test_util.dart';

void main() {
  late RelicServer server;

  tearDown(() => server.close(force: true));

  // dart:io delivers the body after the handler ran, so a subscription
  // taken in the handler has seen nothing when the hijack is asked for.
  test('Given a chunked request body, '
      'when the handler starts reading it and hijacks before its end, '
      'then the server answers 500', () async {
    server = await testServe((req) {
      req.body.read().listen(null);
      return Hijack((channel) {});
    });

    final reply = await rawExchange(
      server.url.port,
      'POST / HTTP/1.1\r\nHost: x\r\nTransfer-Encoding: chunked\r\n'
      'Connection: close\r\n\r\n5\r\nhello\r\n0\r\n\r\n',
    );

    expect(reply, startsWith('HTTP/1.1 500'));
  });
}
