// Relic Migration Examples. Complete code examples from the Shelf to Relic
// migration guide.

import 'dart:developer';
// doctag<complete-relic>
import 'package:relic/io_adapter.dart';
import 'package:relic/relic.dart';

void main() async {
  final app =
      RelicApp()
        ..use('/', logRequests()) // Apply logging to all routes.
        ..get('/users/:id', (final Request req) {
          final id = req.pathParameters[#id]!;
          final name = req.url.queryParameters['name'] ?? 'Unknown';
          return Response.ok(body: Body.fromString('User $id: $name'));
        });

  await app.serve();
}
// end:doctag<complete-relic>

// doctag<websocket-relic>
WebSocketUpgrade websocketHandler(final Request req) {
  return WebSocketUpgrade((final ws) async {
    ws.events.listen((final event) {
      log('Received: $event');
    });

    // Non-throwing variant - returns false if connection is closed.
    ws.trySendText('Hello!');

    // Or, use the throwing variant if you want exceptions.
    ws.sendText('Hello!');
  });
}

// end:doctag<websocket-relic>
