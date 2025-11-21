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

  // Convenience methods that wrap the core .add() method for common HTTP verbs.
  // Handle GET requests to the root path.
  // doctag<routing-basic-get-root>
  app.get('/', (final req) {
    return Response.ok(body: Body.fromString('Hello World!'));
  });
  // end:doctag<routing-basic-get-root>

  // Handle POST requests to the root path.
  // doctag<routing-basic-post-root>
  app.post('/', (final req) {
    return Response.ok(body: Body.fromString('Got a POST request'));
  });
  // end:doctag<routing-basic-post-root>

  // Handle PUT requests to the /user path.
  // doctag<routing-basic-put-user>
  app.put('/user', (final req) {
    return Response.ok(body: Body.fromString('Got a PUT request at /user'));
  });
  // end:doctag<routing-basic-put-user>

  // Handle DELETE requests to the /user path.
  // doctag<routing-basic-delete-user>
  app.delete('/user', (final req) {
    return Response.ok(body: Body.fromString('Got a DELETE request at /user'));
  });
  // end:doctag<routing-basic-delete-user>

  // Use the core .add method directly for more control.
  // This demonstrates the underlying method that convenience methods use.
  // doctag<routing-basic-patch-api>
  app.add(Method.patch, '/api', (final req) {
    return Response.ok(body: Body.fromString('Got a PATCH request at /api'));
  });
  // end:doctag<routing-basic-patch-api>

  // Use .anyOf to handle multiple HTTP methods with a single handler.
  // doctag<routing-basic-anyof-admin>
  app.anyOf({Method.get, Method.post}, '/admin', (final req) {
    final method = req.method.name.toUpperCase();
    return Response.ok(body: Body.fromString('Admin page - $method request'));
  });
  // end:doctag<routing-basic-anyof-admin>

  // Set up a fallback handler for routes that don't match any defined routes.
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
