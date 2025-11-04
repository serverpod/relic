import 'dart:convert';
import 'dart:developer';

import 'package:relic/io_adapter.dart';
import 'package:relic/relic.dart';
import 'package:web_socket/web_socket.dart';

/// Demonstrates the four main context types in Relic using proper routing:
/// - RequestContext: Starting point for all requests
/// - ResponseContext: HTTP response handling
/// - ConnectionContext: WebSocket connections
/// - HijackedContext: Raw connection control

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
        <li><a href="/ws">WebSocket Example (ConnectionContext)</a></li>
        <li><a href="/custom">Custom Protocol (HijackedContext)</a></li>
    </ul>
    <p>This demonstrates the different context types in Relic using proper routing.</p>
</body>
</html>
''';
}

Future<ResponseContext> homeHandler(final Request ctx) async {
  return Response.ok(
    body: Body.fromString(
      _htmlHomePage(),
      encoding: utf8,
      mimeType: MimeType.html,
    ),
  );
}

Future<ResponseContext> apiHandler(final Request ctx) async {
  final data = {
    'message': 'Hello from Relic API!',
    'timestamp': DateTime.now().toIso8601String(),
    'path': ctx.url.path,
  };

  return Response.ok(
    body: Body.fromString(jsonEncode(data), mimeType: MimeType.json),
  );
}

Future<ResponseContext> userHandler(final Request ctx) async {
  final userId = ctx.pathParameters[#id];
  final data = {
    'userId': userId,
    'message': 'User details for ID: $userId',
    'timestamp': DateTime.now().toIso8601String(),
  };

  return Response.ok(
    body: Body.fromString(jsonEncode(data), mimeType: MimeType.json),
  );
}

ConnectionContext webSocketHandler(final Request ctx) {
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

HijackedContext customProtocolHandler(final Request ctx) {
  return ctx.hijack((final channel) {
    log('Connection hijacked for custom protocol');

    // Send a custom HTTP response manually
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

Future<ResponseContext> dataHandler(final Request ctx) async {
  final request = ctx;

  // Access basic HTTP information
  final method = request.method; // 'GET', 'POST', etc.
  final path = request.url.path; // '/api/users'
  final query = request.url.query; // 'limit=10&offset=0'

  log('method: $method, path: $path, query: $query');

  // Access headers (these are typed accessors from the Headers class)
  final authHeader = request.headers.authorization; // 'Bearer token123' or null
  final contentType =
      request
          .body
          .bodyType
          ?.mimeType; // appljson, octet-stream, plainText, etc. or null

  log('authHeader: $authHeader, contentType: $contentType');

  // Read request body for POST with JSON
  if (method == Method.post && contentType == MimeType.json) {
    try {
      final bodyString = await request.readAsString();
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

void main() async {
  // Set up the router with proper routes
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

  // Start the server
  await app.serve();
  log('Context example server running on http://localhost:8080');
  log('Try:');
  log('  - http://localhost:8080/ (HTML page)');
  log('  - http://localhost:8080/api (JSON API)');
  log('  - http://localhost:8080/api/users/123 (API with parameters)');
  log('  - ws://localhost:8080/ws (WebSocket)');
  log('  - http://localhost:8080/custom (Custom protocol)');
}
