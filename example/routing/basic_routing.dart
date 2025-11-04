import 'dart:developer';

import 'package:relic/io_adapter.dart';
import 'package:relic/relic.dart';

/// A simple example demonstrating basic routing in Relic.
///
/// This example shows how to:
/// - Define routes using convenience methods (.get, .post, .put, .delete)
/// - Define routes using the core .add method
/// - Handle requests to different paths
/// - Return appropriate responses
///
/// Try it:
/// - GET  http://localhost:8080/          -> "Hello World!"
/// - POST http://localhost:8080/          -> "Got a POST request"
/// - PUT  http://localhost:8080/user      -> "Got a PUT request at /user"
/// - DELETE http://localhost:8080/user    -> "Got a DELETE request at /user"
/// - PATCH http://localhost:8080/api      -> "Got a PATCH request at /api"
/// - GET  http://localhost:8080/admin     -> "Admin page"
Future<void> main() async {
  final app = RelicApp();

  // Convenience methods - syntactic sugar for .add()
  // Respond with "Hello World!" on the homepage
  // doctag<routing-basic-get-root>
  app.get('/', (final ctx) {
    return ctx.respond(Response.ok(body: Body.fromString('Hello World!')));
  });
  // end:doctag<routing-basic-get-root>

  // Respond to a POST request on the root route
  // doctag<routing-basic-post-root>
  app.post('/', (final ctx) {
    return ctx.respond(
      Response.ok(body: Body.fromString('Got a POST request')),
    );
  });
  // end:doctag<routing-basic-post-root>

  // Respond to a PUT request to the /user route
  // doctag<routing-basic-put-user>
  app.put('/user', (final ctx) {
    return ctx.respond(
      Response.ok(body: Body.fromString('Got a PUT request at /user')),
    );
  });
  // end:doctag<routing-basic-put-user>

  // Respond to a DELETE request to the /user route
  // doctag<routing-basic-delete-user>
  app.delete('/user', (final ctx) {
    return ctx.respond(
      Response.ok(body: Body.fromString('Got a DELETE request at /user')),
    );
  });
  // end:doctag<routing-basic-delete-user>

  // Using the core .add method directly
  // This is what the convenience methods (.get, .post, etc.) call internally
  // doctag<routing-basic-patch-api>
  app.add(Method.patch, '/api', (final ctx) {
    return ctx.respond(
      Response.ok(body: Body.fromString('Got a PATCH request at /api')),
    );
  });
  // end:doctag<routing-basic-patch-api>

  // Using .anyOf to handle multiple methods with the same handler
  // doctag<routing-basic-anyof-admin>
  app.anyOf({Method.get, Method.post}, '/admin', (final ctx) {
    final method = ctx.request.method.name.toUpperCase();
    return ctx.respond(
      Response.ok(body: Body.fromString('Admin page - $method request')),
    );
  });
  // end:doctag<routing-basic-anyof-admin>

  // Combine router with fallback for unmatched routes
  app.fallback = respondWith((final _) => Response.notFound());

  await app.serve();
  log('Server running on http://localhost:8080');
  log('Try:');
  log('  curl http://localhost:8080/');
  log('  curl -X POST http://localhost:8080/');
  log('  curl -X PUT http://localhost:8080/user');
  log('  curl -X DELETE http://localhost:8080/user');
  log('  curl -X PATCH http://localhost:8080/api');
  log('  curl http://localhost:8080/admin');
  log('  curl -X POST http://localhost:8080/admin');
}
