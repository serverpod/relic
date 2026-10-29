import 'dart:io';
import 'dart:isolate';

import 'package:relic/relic.dart';

// doctag<serving-isolate-state>
// Each isolate has its own copy of this variable.
var served = 0;

Response count(Request req) {
  served++;
  return Response.ok(
    body: .fromString('isolate ${Isolate.current.hashCode} served $served\n'),
  );
}
// end:doctag<serving-isolate-state>

Future<void> main(List<String> args) async {
  final isolates = args.isEmpty ? 1 : int.parse(args.first);
  final app = RelicApp()..get('/count', count);

  // doctag<serving-serve>
  final server = await app.serve(
    address: InternetAddress.anyIPv4,
    port: 8080,
    noOfIsolates: isolates,
  );
  stdout.writeln('Listening on port ${server.port} with $isolates isolate(s)');

  await ProcessSignal.sigint.watch().first;
  await app.close();
  stdout.writeln('Closed');
  // end:doctag<serving-serve>
}
