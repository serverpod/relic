import 'dart:io';

import 'package:relic/relic.dart';
import 'package:relic_native/relic_native.dart';

// doctag<serving-native>
Future<void> main(List<String> args) async {
  final isolates = args.isEmpty ? 1 : int.parse(args.first);
  final app = RelicApp()
    ..get('/', (req) => Response.ok(body: .fromString('Hello\n')));

  final server = await app.serveNative(port: 8080, noOfIsolates: isolates);
  stdout.writeln('Listening on port ${server.port} with $isolates isolate(s)');
}

// end:doctag<serving-native>
