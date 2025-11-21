import 'dart:io';

import 'package:relic/io_adapter.dart';
import 'package:relic/relic.dart';

Future<void> main() async {
  // Create a router that handles all requests with the same response.
  final router =
      RelicRouter()
        ..use('/', logRequests()) // Apply logging middleware to all routes.
        ..any(
          '/**',
          respondWith(
            (final request) =>
                Response.ok(body: Body.fromString('Hello, Relic!')),
          ),
        );

  // Create and start a server using the low-level RelicServer API.
  final server = RelicServer(
    () => IOAdapter.bind(InternetAddress.anyIPv4, port: 8080),
  );

  // Convert router to handler and start serving.
  await server.mountAndStart(router.asHandler);
}
