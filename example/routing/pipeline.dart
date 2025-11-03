import 'dart:io';

import 'package:relic/io_adapter.dart';
import 'package:relic/relic.dart';

/// A pipeline 'Hello World' server
// doctag<10-pipeline-6>
Future<void> main() async {
  // Create a pipeline that route all request to the same handler
  final handler = const Pipeline()
      // Pipelines allows middleware to run before routing
      .addMiddleware(logRequests())
      .addHandler(
        respondWith(
          (final request) =>
              Response.ok(body: Body.fromString('Hello, Relic!')),
        ),
      ); // handles any verb, and any path

  // Start a server that forward request to the handler
  final server = RelicServer(
    () => IOAdapter.bind(InternetAddress.anyIPv4, port: 8080),
  );
  await server.mountAndStart(handler);
}
// end:doctag<10-pipeline-6>
