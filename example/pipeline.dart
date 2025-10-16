import 'dart:io';

import 'package:relic/io_adapter.dart';
import 'package:relic/relic.dart';

/// A pipeline 'Hello World' server
Future<void> main() async {
  // Create a pipeline that route all request to the same handler
  final handler = const Pipeline()
      // Pipelines allows middleware to run before routing
      .addMiddleware(logRequests())
      .addHandler(respondWith(
        (final request) => Response.ok(
          body: Body.fromString('Hello, Relic!'),
        ),
      )); // handles any verb, and any path

  // Start a server that forward request to the handler
  final adapter = await IOAdapter.bind(InternetAddress.anyIPv4, port: 8080);
  final server = RelicServer(adapter);
  await server.mountAndStart(handler);
}
