import 'dart:io';

import 'package:relic/io_adapter.dart';
import 'package:relic/relic.dart';

/// Demonstrates using the Pipeline API for request processing.
// doctag<routing-pipeline-hello-world>
Future<void> main() async {
  // Build a request processing pipeline with middleware and a handler.
  final handler = const Pipeline()
      // Add logging middleware to the pipeline.
      .addMiddleware(logRequests())
      // This handler responds to all HTTP methods and paths.
      .addHandler(
        respondWith(
          (final request) =>
              Response.ok(body: Body.fromString('Hello, Relic!')),
        ),
      );

  // Create and start a server using the pipeline handler.
  final server = RelicServer(
    () => IOAdapter.bind(InternetAddress.anyIPv4, port: 8080),
  );
  await server.mountAndStart(handler);
}

// end:doctag<routing-pipeline-hello-world>
