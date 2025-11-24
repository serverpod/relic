import 'dart:developer';
import 'dart:io';

/// Complete code sample referenced by the Shelf migration guide.
// doctag<complete-relic>
import 'package:relic/io_adapter.dart';
import 'package:relic/relic.dart';

Future<void> main() async {
  final app =
      RelicApp()..get('/users/:id', (final Request request) {
        final id = request.pathParameters[#id];
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

    ws.trySendText('Hello!');
    ws.sendText('Hello!');
  });
}

// end:doctag<websocket-relic>
