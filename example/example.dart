// ignore_for_file: avoid_print
import 'dart:io';
import 'dart:isolate';

import 'package:relic/relic.dart';

void main() async {
  final isolateCount = Platform.numberOfProcessors * 2;

  print('Starting $isolateCount isolates');
  final isolates = await Future.wait(List.generate(
      isolateCount,
      (final index) =>
          Isolate.spawn((final _) => _serve(), null, debugName: '$index')));

  await ProcessSignal.sigint.watch().first;

  for (final i in isolates) {
    i.kill(priority: Isolate.immediate);
  }
}

Future<void> _serve() async {
  final handler =
      const Pipeline().addMiddleware(logRequests()).addHandler(_echoRequest);
  await serve(handler, InternetAddress.anyIPv4, 8080, shared: true);
  print('serving on ${Isolate.current.debugName}');
}

Response _echoRequest(final Request request) {
  sleep(const Duration(seconds: 1)); // pretend to be really slow
  return Response.ok(
    body: Body.fromString(
      'Request for "${request.url}" handled by isolate ${Isolate.current.debugName}',
    ),
  );
}
