import 'dart:convert';
import 'dart:developer';

import 'package:relic/io_adapter.dart';
import 'package:relic/relic.dart';
import 'package:web_socket/web_socket.dart';

/// Demonstrates the four main context types in Relic using proper routing:
/// - NewContext: Starting point for all requests
/// - ResponseContext: HTTP response handling
/// - ConnectContext: WebSocket connections
/// - HijackContext: Raw connection control

/// Simple HTML page for demonstration
String _htmlHomePage() {
  return '''
<!DOCTYPE html>
<html>
<head>
    <title>Relic Context Example</title>
</head>
<body>
    <h1>Relic Context Types Demo</h1>
    <ul>
        <li><a href="/api">API Example (ResponseContext)</a></li>
        <li><a href="/api/users/123">User API with Parameters (ResponseContext)</a></li>
        <li><a href="/ws">WebSocket Example (ConnectContext)</a></li>
        <li><a href="/custom">Custom Protocol (HijackContext)</a></li>
    </ul>
    <p>This demonstrates the different context types in Relic using proper routing.</p>
</body>
</html>
''';
}

/// Example 1: HTTP Response (NewContext -> ResponseContext)
Future<ResponseContext> homeHandler(final NewContext ctx) async {
  return ctx.respond(Response.ok(
    body: Body.fromString(
      _htmlHomePage(),
      encoding: utf8,
      mimeType: MimeType.html,
    ),
  ));
}

/// Example 2: JSON API Response (NewContext -> ResponseContext)
Future<ResponseContext> apiHandler(final NewContext ctx) async {
  final data = {
    'message': 'Hello from Relic API!',
    'timestamp': DateTime.now().toIso8601String(),
    'path': ctx.request.url.path,
  };

  return ctx.respond(Response.ok(
    body: Body.fromString(
      jsonEncode(data),
      mimeType: MimeType.json,
    ),
  ));
}

/// Example 3: WebSocket Connection (NewContext -> ConnectContext)
ConnectContext webSocketHandler(final NewContext ctx) {
  return ctx.connect((final webSocket) async {
    log('WebSocket connection established');

    // Send welcome message
    webSocket.sendText('Welcome to Relic WebSocket!');

    // Echo incoming messages
    await for (final event in webSocket.events) {
      switch (event) {
        case TextDataReceived(text: final message):
          log('Received: $message');
          webSocket.sendText('Echo: $message');
        case CloseReceived():
          log('WebSocket connection closed');
          break;
        default:
          // Handle other event types if needed
          break;
      }
    }
  });
}

/// Example 4: Raw Connection Hijack (NewContext -> HijackContext)
HijackContext customProtocolHandler(final NewContext ctx) {
  return ctx.hijack((final channel) {
    log('Connection hijacked for custom protocol');

    // Send a custom HTTP response manually
    const response = 'HTTP/1.1 200 OK\r\n'
        'Content-Type: text/plain\r\n'
        'Connection: close\r\n'
        '\r\n'
        'Custom protocol response from Relic!';

    channel.sink.add(utf8.encode(response));
    channel.sink.close();
  });
}

void main() async {
  // Set up the router with proper routes
  final app = RelicApp()
    ..get('/', homeHandler) // Home page
    ..get('/api', apiHandler) // Simple API
    ..get('/ws', webSocketHandler) // WebSocket
    ..get('/custom', customProtocolHandler) // Custom protocol
    ..fallback = respondWith(
      (final request) => Response.notFound(
        body: Body.fromString('Page not found'),
      ),
    );

  // Start the server
  await app.serve();
  log('Context example server running on http://localhost:8080');
  log('Try:');
  log('  - http://localhost:8080/ (HTML page)');
  log('  - http://localhost:8080/api (JSON API)');
  log('  - ws://localhost:8080/ws (WebSocket)');
  log('  - http://localhost:8080/custom (Custom protocol)');
}
