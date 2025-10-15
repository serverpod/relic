import 'dart:developer';
import 'dart:io';
import 'package:relic/io_adapter.dart';
import 'package:relic/relic.dart';

Future<void> main() async {
  // Create a simple handler that responds to every request
  final router = RelicRouter()
    // Public routes
    ..get(
      '/public',
      (final ctx) => ctx.respond(
        Response.ok(
          body: Body.fromString('Hello, Relic!'),
        ),
      ),
    );

  // Start the server on all network interfaces, port 8080
  await serve(router.asHandler, InternetAddress.anyIPv4, 8080);
  log('Server running on http://localhost:8080');
}
