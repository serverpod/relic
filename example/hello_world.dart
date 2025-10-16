import 'dart:developer';

import 'package:relic/io_adapter.dart';
import 'package:relic/relic.dart';

Future<void> main() async {
  // Create a simple app that responds to every request
  final app = RelicApp()
    ..any(
        '/**',
        respondWith(
          (final request) => Response.ok(
            body: Body.fromString('Hello, Relic!'),
          ),
        ));

  // Start the server. Defaults to using port 8080 on loopback interface
  await app.serve();
  log('Server running on http://localhost:8080');
}
