import 'dart:developer';
import 'package:relic/io_adapter.dart';
import 'package:relic/relic.dart';

Future<void> main() async {
  // Create a simple handler that responds to every request
  final app = RelicApp()
    ..get(
      '/**',
      (final ctx) => ctx.respond(
        Response.ok(
          body: Body.fromString('Hello, Relic!'),
        ),
      ),
    );

  // Start the server on port 8080
  await app.serve(port: 8080);

  log('Server running on http://localhost:8080');
}