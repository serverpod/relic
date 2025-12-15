import 'dart:developer';
import 'dart:io';
import 'dart:isolate';

import 'package:relic/io_adapter.dart';
import 'package:relic/relic.dart';

void main() async {
  // Calculate the number of isolates based on available CPU cores.
  // Using 2x the processor count ensures optimal hardware utilization.
  final isolateCount = Platform.numberOfProcessors * 2;

  // Spawn all isolates concurrently and wait for them to start.
  log('Starting $isolateCount isolates');
  final isolates = await List.generate(
    isolateCount,
    (final index) =>
        Isolate.spawn((final _) => _serve(), null, debugName: '$index'),
  ).wait;

  // Wait for SIGINT (Ctrl-C) or SIGTERM signal before shutting down.
  await Future.any(
    [
      ProcessSignal.sigterm,
      ProcessSignal.sigint,
    ].map((final s) => s.watch().first),
  );

  // Gracefully terminate all spawned isolates.
  for (final i in isolates) {
    i.kill(priority: Isolate.immediate);
  }
}

/// Starts a Relic server in each spawned isolate for load balancing.
Future<void> _serve() async {
  // Create a simple app with logging middleware and an echo endpoint.
  final app = RelicApp()
    ..use('/', logRequests())
    ..put('/echo', respondWith(_echoRequest));

  // Start the server with shared socket binding for load balancing.
  await app.serve(shared: true);

  log('serving on ${Isolate.current.debugName}');
}

/// Echoes the request path and shows which isolate handled it.
Response _echoRequest(final Request req) {
  // Simulate slow processing to demonstrate load balancing.
  sleep(const Duration(seconds: 1));
  return Response.ok(
    body: Body.fromString(
      'Request for "${req.url}" '
      'handled by isolate ${Isolate.current.debugName}',
    ),
  );
}
