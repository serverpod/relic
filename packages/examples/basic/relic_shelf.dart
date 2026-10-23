import 'dart:developer';

// doctag<complete-relic>
import 'dart:io';

import 'package:relic/relic.dart';

Future<void> main() async {
  final app = RelicApp()
    ..use('/', logRequests())
    ..get('/users/:id', (final Request request) {
      final id = request.rawPathParameters[#id];
      final name = request.url.queryParameters['name'] ?? 'Unknown';
      return Response.ok(body: Body.fromString('User $id: $name'));
    });

  await app.serve(address: InternetAddress.loopbackIPv4, port: 8080);
}
// end:doctag<complete-relic>

/// Handles WebSocket connections with event logging.
// doctag<websocket-relic>
WebSocketUpgrade websocketHandler(final Request request) {
  return WebSocketUpgrade((final ws) async {
    ws.events.listen((final event) {
      log('Received: $event');
    });

    ws.sendText('Hello!');
  });
}

// end:doctag<websocket-relic>
