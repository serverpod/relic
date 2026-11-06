import 'dart:io' as io;

import 'package:relic_core/relic_core.dart';
import 'package:test/test.dart';
import 'package:test_utils/adapter_conformance.dart';

import '../util/test_util.dart';

void main() {
  late RelicServer server;

  tearDown(() => server.close());

  test('Given a request with a DEL byte inside a field name, '
      'when it is served, '
      'then it is answered with 400 before the handler runs.', () async {
    var handled = 0;
    server = await testServe((req) {
      handled++;
      return Response.ok();
    });

    final socket = await io.Socket.connect('127.0.0.1', server.url.port);
    socket.add([
      ...'GET / HTTP/1.1\r\nHost: x\r\nx-a'.codeUnits,
      0x7f,
      ...'b: c\r\nConnection: close\r\n\r\n'.codeUnits,
    ]);
    final bytes = await socket
        .fold<List<int>>([], (a, b) => a..addAll(b))
        .timeout(const Duration(seconds: 5), onTimeout: () => const []);

    expect(String.fromCharCodes(bytes), startsWith('HTTP/1.1 400'));
    expect(handled, 0);
  });
}
