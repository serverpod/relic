import 'dart:developer';

import 'package:relic/io_adapter.dart';
import 'package:relic/relic.dart';

/// Extension to provide easy access to the request ID.
// doctag<context-prop-request-id>
extension on Request {
  String get requestId => _requestIdProperty.get(this);
}

final _requestIdProperty = ContextProperty<String>('requestId');

// Middleware that generates and stores a unique ID for each request.
Handler requestIdMiddleware(final Handler next) {
  return (final req) async {
    // Generate a timestamp-based unique ID for this request.
    _requestIdProperty[req] = 'req_${DateTime.now().millisecondsSinceEpoch}';

    // Pass control to the next handler in the chain.
    return await next(req);
  };
}
// end:doctag<context-prop-request-id>

// doctag<context-prop-use-request-id>
// Handler that retrieves and displays the request ID.
Future<Response> handler(final Request req) async {
  // Access the request ID (set by the middleware) using the extension method.
  final requestId = req.requestId;

  log('Request ID: $requestId');

  return Response.ok(body: Body.fromString('Your request ID is: $requestId'));
}
// end:doctag<context-prop-use-request-id>

/// Demonstrates using ContextProperty for request-scoped data storage.
void main() async {
  // Configure the application with middleware and routes.
  final app = RelicApp()
    // Apply request ID middleware globally.
    ..use('/', requestIdMiddleware)
    // Route that displays the request ID.
    ..get('/', handler);

  await app.serve();
  log('Server running on http://localhost:8080');

  log('ContextProperty example - stores request-specific data');
  log('Each request gets a unique ID that can be accessed by any handler');
}
