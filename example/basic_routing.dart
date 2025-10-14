// ignore_for_file: avoid_print, prefer_final_parameters

import 'dart:io';
import 'package:relic/io_adapter.dart';
import 'package:relic/relic.dart';

/// A simple example demonstrating basic routing in Relic.
///
/// This example shows how to:
/// - Define routes for different HTTP methods (GET, POST, PUT, DELETE)
/// - Handle requests to different paths
/// - Return appropriate responses
///
/// Try it:
/// - GET  http://localhost:8080/          -> "Hello World!"
/// - POST http://localhost:8080/          -> "Got a POST request"
/// - PUT  http://localhost:8080/user      -> "Got a PUT request at /user"
/// - DELETE http://localhost:8080/user    -> "Got a DELETE request at /user"
Future<void> main() async {
  final router = Router<Handler>();

  // Respond with "Hello World!" on the homepage
  router.get('/', (ctx) {
    return ctx.respond(
      Response.ok(
        body: Body.fromString('Hello World!'),
      ),
    );
  });

  // Respond to a POST request on the root route
  router.post('/', (ctx) {
    return ctx.respond(
      Response.ok(
        body: Body.fromString('Got a POST request'),
      ),
    );
  });

  // Respond to a PUT request to the /user route
  router.put('/user', (ctx) {
    return ctx.respond(
      Response.ok(
        body: Body.fromString('Got a PUT request at /user'),
      ),
    );
  });

  // Respond to a DELETE request to the /user route
  router.delete('/user', (ctx) {
    return ctx.respond(
      Response.ok(
        body: Body.fromString('Got a DELETE request at /user'),
      ),
    );
  });

  // Combine router with fallback for unmatched routes
  final handler = const Pipeline()
      .addMiddleware(routeWith(router))
      .addHandler(respondWith((_) => Response.notFound()));

  await serve(handler, InternetAddress.anyIPv4, 8080);
  print('Server running on http://localhost:8080');
  print('Try:');
  print('  curl http://localhost:8080/');
  print('  curl -X POST http://localhost:8080/');
  print('  curl -X PUT http://localhost:8080/user');
  print('  curl -X DELETE http://localhost:8080/user');
}
