// Example showing how to use the platform-agnostic abstraction
// ignore_for_file: avoid_print

import 'package:relic/relic.dart';

void main() async {
  // Create a simple handler
  Response handler(final Request request) {
    return Response.ok(
      body: Body.fromString('Hello from ${request.requestedUri.path}'),
    );
  }

  // Use the platform-agnostic API
  final server = await serve(
    handler,
    Address.loopback(), // Platform-agnostic address
    8080,
    strictHeaders: false,
  );

  print('Serving at http://localhost:${server.adaptor.port}');

  // The server will run until manually stopped
  // For a real application, you would want to handle SIGINT/SIGTERM
  // and call server.close() when shutting down
}
