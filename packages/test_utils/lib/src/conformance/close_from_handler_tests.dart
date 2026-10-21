import 'dart:async';
import 'dart:io';

import 'package:http/http.dart' as http;
import 'package:relic_core/relic_core.dart';
import 'package:test/test.dart';

import 'conformance.dart';

/// A handler may close the server it runs on, from inside an exchange.
void closeFromHandlerTests(AdapterConformance conformance) {
  RelicServer? server;

  tearDown(() async {
    await server?.close(force: true);
    server = null;
  });

  test('Given a handler that closes its own server forcefully, '
      'when a request reaches it, '
      'then the close completes and the port is released', () async {
    final closed = Completer<void>();
    server = await conformance.serve((req) {
      closed.complete(server!.close(force: true));
      return Response.ok(body: Body.fromString('bye'));
    });
    final port = server!.port;

    try {
      await http.get(server!.url);
    } on http.ClientException {
      // Closing the server may drop the connection. Either outcome is fine.
    }

    await expectLater(
      closed.future.timeout(const Duration(seconds: 5)),
      completes,
    );
    await expectLater(
      Socket.connect(InternetAddress.loopbackIPv4, port),
      throwsA(isA<SocketException>()),
      reason: 'The listener must be gone after a forced close',
    );
  });

  test('Given a handler that closes its own server gracefully, '
      'when a request reaches it, '
      'then the response goes out and the close completes', () async {
    final closed = Completer<void>();
    server = await conformance.serve((req) {
      closed.complete(server!.close());
      return Response.ok(body: Body.fromString('bye'));
    });

    final response = await http.get(server!.url);

    expect(response.body, 'bye');
    await expectLater(
      closed.future.timeout(const Duration(seconds: 5)),
      completes,
    );
  });
}
