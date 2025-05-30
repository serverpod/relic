// ignore_for_file: avoid_print
import 'dart:io';
import 'dart:isolate';

import 'package:relic/io_adapter.dart';
import 'package:relic/relic.dart';

void main() async {
  // The number of isolates to use. Making it proportional to number of
  // processors ensure we have enough isolates to utilize the hardware.
  final isolateCount = Platform.numberOfProcessors * 2;

  // Wait for all the isolates to spawn
  print('Starting $isolateCount isolates');
  final isolates = await Future.wait(List.generate(
      isolateCount,
      (final index) =>
          Isolate.spawn((final _) => _serve(), null, debugName: '$index')));

  // Wait for Ctrl-C before proceeding
  await ProcessSignal.sigint.watch().first;

  // Shutdown again.
  for (final i in isolates) {
    i.kill(priority: Isolate.immediate);
  }
}

/// [_serve] is called in each spawned isolate.
Future<void> _serve() async {
  ///
  final handler = const Pipeline()
      .addMiddleware(logRequests()) // setup logging
      .addHandler(respondWith(_echoRequest)); // add our handler

  // start the server
  await serve(handler, InternetAddress.anyIPv4, 8080, shared: true);
  print('serving on ${Isolate.current.debugName}');
}

/// [_echoRequest] just echoes the path of the request
Response _echoRequest(final Request request) {
  sleep(const Duration(seconds: 1)); // pretend to be really slow
  return Response.ok(
    body: Body.fromString(
      'Request for "${request.url}" handled by isolate ${Isolate.current.debugName}',
    ),
  );
}
