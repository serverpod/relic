import 'dart:developer';
import 'dart:io';
import 'dart:isolate';

import 'package:relic/io_adapter.dart';
import 'package:relic/relic.dart';

void main() async {
  // The number of isolates to use. Making it proportional to number of
  // processors ensure we have enough isolates to utilize the hardware.
  final isolateCount = Platform.numberOfProcessors * 2;

  // Wait for all the isolates to spawn
  log('Starting $isolateCount isolates');
  final isolates = await Future.wait(
    List.generate(
      isolateCount,
      (final index) =>
          Isolate.spawn((final _) => _serve(), null, debugName: '$index'),
    ),
  );

  // Wait for Ctrl-C before proceeding
  await ProcessSignal.sigint.watch().first;

  // Shutdown again.
  for (final i in isolates) {
    i.kill(priority: Isolate.immediate);
  }
}

/// [_serve] is called in each spawned isolate.
Future<void> _serve() async {
  // A router with no routes but a fallback
  final app =
      RelicApp()
        ..use('/', logRequests())
        ..put('/echo', respondWith(_echoRequest));

  // start the server
  await app.serve(shared: true);

  log('serving on ${Isolate.current.debugName}');
}

/// [_echoRequest] just echoes the path of the request
Response _echoRequest(final Request req) {
  sleep(const Duration(seconds: 1)); // pretend to be really slow
  return Response.ok(
    body: Body.fromString(
      'Request for "${req.requestedUri}" handled by isolate ${Isolate.current.debugName}',
    ),
  );
}
