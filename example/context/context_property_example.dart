import 'dart:developer';

import 'package:relic/io_adapter.dart';
import 'package:relic/relic.dart';

// Create a ContextProperty to store request-specific data
// doctag<08-context-property-7>
final _requestIdProperty = ContextProperty<String>('requestId');

// Middleware that sets a unique ID for each request
Handler requestIdMiddleware(final Handler next) {
  return (final ctx) async {
    // Set a unique request ID
    _requestIdProperty[ctx] = 'req_${DateTime.now().millisecondsSinceEpoch}';

    // Continue to the next handler
    return await next(ctx);
  };
}
// end:doctag<08-context-property-7>

// Handler that uses the stored request ID
// doctag<08-context-property-21>
Future<ResponseContext> handler(final RequestContext ctx) async {
  // Retrieve the request ID that was set by middleware
  final requestId = _requestIdProperty[ctx];

  log('Request ID: $requestId');

  return ctx.respond(
    Response.ok(body: Body.fromString('Your request ID is: $requestId')),
  );
}
// end:doctag<08-context-property-21>

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
