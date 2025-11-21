import 'dart:convert';
import 'dart:developer';

import 'package:relic/io_adapter.dart';
import 'package:relic/relic.dart';
import 'package:web_socket/web_socket.dart';

/// Demonstrates the four main context types in Relic:
/// - Request: Standard HTTP request handling.
/// - Response: HTTP response creation.
/// - WebSocketUpgrade: Real-time WebSocket connections.
/// - Hijack: Low-level connection control.

/// Generates an HTML page that links to all example endpoints.
// doctag<context-html-homepage>
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
        <li><a href="/api">API Example (Response)</a></li>
        <li><a href="/api/users/123">User API with Parameters (Response)</a></li>
        <li><a href="/ws">WebSocket Example (WebSocketUpgrade)</a></li>
        <li><a href="/custom">Custom Protocol (Hijack)</a></li>
    </ul>
    <p>This demonstrates the different context types in Relic using proper routing.</p>
</body>
</html>
''';
}

/// Serves the main HTML page with links to all examples.
Future<Response> homeHandler(final Request req) async {
  return Response.ok(
    body: Body.fromString(
      _htmlHomePage(),
      encoding: utf8,
      mimeType: MimeType.html,
    ),
  );
}
// end:doctag<context-html-homepage>

// doctag<context-api-json>
Future<Response> apiHandler(final Request req) async {
  final data = {
    'message': 'Hello from Relic API!',
    'timestamp': DateTime.now().toIso8601String(),
    'path': req.url.path,
  };

  return Response.ok(
    body: Body.fromString(jsonEncode(data), mimeType: MimeType.json),
  );
}
// end:doctag<context-api-json>

/// Returns user information based on the provided ID parameter.
Future<Response> userHandler(final Request req) async {
  final userId = req.pathParameters[#id];
  final data = {
    'userId': userId,
    'message': 'User details for ID: $userId',
    'timestamp': DateTime.now().toIso8601String(),
  };

  return Response.ok(
    body: Body.fromString(jsonEncode(data), mimeType: MimeType.json),
  );
}

// doctag<context-websocket-echo>
WebSocketUpgrade webSocketHandler(final Request req) {
  return WebSocketUpgrade((final webSocket) async {
    log('WebSocket connection established');

    // Send initial greeting to the connected client.
    webSocket.sendText('Welcome to Relic WebSocket!');

    // Listen for messages and echo them back to the client.
    await for (final event in webSocket.events) {
      switch (event) {
        case TextDataReceived(text: final message):
          log('Received: $message');
          webSocket.sendText('Echo: $message');
        case CloseReceived():
          log('WebSocket connection closed');
          break;
        default:
          // Handle binary data, ping/pong, and other WebSocket events.
          break;
      }
    }
  });
}
// end:doctag<context-websocket-echo>

/// Demonstrates connection hijacking for custom protocols.
Hijack customProtocolHandler(final Request req) {
  return Hijack((final channel) {
    log('Connection hijacked for custom protocol');

    // Manually craft and send a raw HTTP response.
    const response =
        'HTTP/1.1 200 OK\r\n'
        'Content-Type: text/plain\r\n'
        'Connection: close\r\n'
        '\r\n'
        'Custom protocol response from Relic!';

    channel.sink.add(utf8.encode(response));
    channel.sink.close();
  });
}

// doctag<context-request-inspect>
Future<Response> dataHandler(final Request req) async {
  // Extract common request information for processing.
  final method = req.method; // 'GET', 'POST', etc.
  final path = req.url.path; // '/api/users'
  final query = req.url.query; // 'limit=10&offset=0'

  log('method: $method, path: $path, query: $query');

  // Access headers (these are typed accessors from the Headers class)
  final authHeader = req.headers.authorization; // 'Bearer token123' or null
  final contentType =
      req
          .body
          .bodyType
          ?.mimeType; // appljson, octet-stream, plainText, etc. or null

  log('authHeader: $authHeader, contentType: $contentType');

  // Read request body for POST with JSON
  if (method == Method.post && contentType == MimeType.json) {
    try {
      final bodyString = await req.readAsString();
      final jsonData = json.decode(bodyString) as Map<String, dynamic>;

      return Response.ok(
        body: Body.fromString('Received: ${jsonData['name']}'),
      );
    } catch (e) {
      return Response.badRequest(body: Body.fromString('Invalid JSON'));
    }
  }

  // Return bad request if the content type is not JSON
  return Response.badRequest(body: Body.fromString('Invalid Request'));
}
// end:doctag<context-request-inspect>

/// Demonstrates the four main context types in Relic with examples.
void main() async {
  // Configure the application with all route handlers.
  final app =
      RelicApp()
        ..get('/', homeHandler) // Home page
        ..get('/api', apiHandler) // Simple API
        ..get('/api/users/:id', userHandler) // API with parameters
        ..get('/ws', webSocketHandler) // WebSocket
        ..get('/custom', customProtocolHandler) // Custom protocol
        ..post('/data', dataHandler) // Data handler
        ..fallback = respondWith(
          (final request) =>
              Response.notFound(body: Body.fromString('Page not found')),
        );

  // Start the server.
  await app.serve();
  log('Context example server running on http://localhost:8080');
  log('Try:');
  log('  - http://localhost:8080/ (HTML page)');
  log('  - http://localhost:8080/api (JSON API)');
  log('  - http://localhost:8080/api/users/123 (API with parameters)');
  log('  - ws://localhost:8080/ws (WebSocket)');
  log('  - http://localhost:8080/custom (Custom protocol)');
}
