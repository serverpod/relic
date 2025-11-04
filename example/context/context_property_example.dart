import 'dart:developer';

import 'package:relic/io_adapter.dart';
import 'package:relic/relic.dart';

// Create a ContextProperty to store request-specific data
// doctag<context-prop-request-id>
final _requestIdProperty = ContextProperty<String>('requestId');

// Middleware that sets a unique ID for each request
Handler requestIdMiddleware(final Handler next) {
  return (final req) async {
    // Set a unique request ID
    _requestIdProperty[req] = 'req_${DateTime.now().millisecondsSinceEpoch}';

    // Continue to the next handler
    return await next(req);
  };
}
// end:doctag<context-prop-request-id>

// doctag<context-prop-use-request-id>
// Handler that uses the stored request ID
Future<Response> handler(final Request req) async {
  // Retrieve the request ID that was set by middleware
  final requestId = _requestIdProperty[req];

  log('Request ID: $requestId');

  return Response.ok(body: Body.fromString('Your request ID is: $requestId'));
}
// end:doctag<context-prop-use-request-id>

void main() async {
  // Set up the router with routes
  final app =
      RelicApp()
        ..use('/', requestIdMiddleware) // Sets the request ID
        ..get('/', handler); // Uses the request ID

  await app.serve();
  log('Server running on http://localhost:8080');

  log('ContextProperty example - stores request-specific data');
  log('Each request gets a unique ID that can be accessed by any handler');
}
