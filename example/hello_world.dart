import 'dart:developer';
import 'dart:io';

import 'package:relic/io_adapter.dart';
import 'package:relic/relic.dart';

Future<void> main() async {
  // Create a simple handler that responds to every request
  final app = RelicApp()
    ..any(
        '/**',
        respondWith(
          (final request) => Response.ok(
            body: Body.fromString('Hello, Relic!'),
          ),
        ));

  // Start the server on all network interfaces, port 8080
  await serve(app.asHandler, InternetAddress.loopbackIPv4, 8080);
  log('Server running on http://localhost:8080');
}
