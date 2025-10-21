// ignore_for_file: avoid_print, prefer_final_parameters

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
  app.get('/', (ctx) {
    return ctx.respond(
      Response.ok(
        body: Body.fromString('Hello World!'),
      ),
    );
  });

  // Respond to a POST request on the root route
  app.post('/', (ctx) {
    return ctx.respond(
      Response.ok(
        body: Body.fromString('Got a POST request'),
      ),
    );
  });

  // Respond to a PUT request to the /user route
  app.put('/user', (ctx) {
    return ctx.respond(
      Response.ok(
        body: Body.fromString('Got a PUT request at /user'),
      ),
    );
  });

  // Respond to a DELETE request to the /user route
  app.delete('/user', (ctx) {
    return ctx.respond(
      Response.ok(
        body: Body.fromString('Got a DELETE request at /user'),
      ),
    );
  });

  // Using the core .add method directly
  // This is what the convenience methods (.get, .post, etc.) call internally
  app.add(Method.patch, '/api', (ctx) {
    return ctx.respond(
      Response.ok(
        body: Body.fromString('Got a PATCH request at /api'),
      ),
    );
  });

  // Using .anyOf to handle multiple methods with the same handler
  app.anyOf({Method.get, Method.post}, '/admin', (ctx) {
    final method = ctx.request.method.name.toUpperCase();
    return ctx.respond(
      Response.ok(
        body: Body.fromString('Admin page - $method request'),
      ),
    );
  });

  // Combine router with fallback for unmatched routes
  app.fallback = respondWith((_) => Response.notFound());

  await app.serve();
  print('Server running on http://localhost:8080');
  print('Try:');
  print('  curl http://localhost:8080/');
  print('  curl -X POST http://localhost:8080/');
  print('  curl -X PUT http://localhost:8080/user');
  print('  curl -X DELETE http://localhost:8080/user');
  print('  curl -X PATCH http://localhost:8080/api');
  print('  curl http://localhost:8080/admin');
  print('  curl -X POST http://localhost:8080/admin');
}
