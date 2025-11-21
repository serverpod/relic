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
  final isolates = await Future.wait(
    List.generate(
      isolateCount,
      (final index) =>
          Isolate.spawn((final _) => _serve(), null, debugName: '$index'),
    ),
  );

  // Wait for SIGINT (Ctrl-C) signal before shutting down.
  await ProcessSignal.sigint.watch().first;

  // Gracefully terminate all spawned isolates.
  for (final i in isolates) {
    i.kill(priority: Isolate.immediate);
  }
}

/// [_serve] is called in each spawned isolate.
Future<void> _serve() async {
  // Create a simple app with logging middleware and an echo endpoint.
  final app =
      RelicApp()
        ..use('/', logRequests())
        ..put('/echo', respondWith(_echoRequest));

  // Start the server with shared socket binding for load balancing.
  await app.serve(shared: true);

  log('serving on ${Isolate.current.debugName}');
}

/// [_echoRequest] just echoes the path of the request
Response _echoRequest(final Request request) {
  // Simulate slow processing to demonstrate load balancing.
  sleep(const Duration(seconds: 1));
  return Response.ok(
    body: Body.fromString(
      'Request for "${request.url}" handled by isolate ${Isolate.current.debugName}',
    ),
  );
}
