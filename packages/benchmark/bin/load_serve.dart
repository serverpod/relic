// The http_load.dart routes for a load tool or profiler started elsewhere.
// Serves them at port 18098 until SIGTERM.
//
//   dart --profiler --profile-period=200 --enable-vm-service=8181 \
//       --disable-service-auth-codes bin/load_serve.dart native 1
//   oha -z 20s -c 64 -H ... http://127.0.0.1:18098/browser
//   dart run bin/cpu_profile.dart ws://127.0.0.1:8181/ws --wait=8 --window=6
//
// `shelf` is a shelf server on dart:io with the same routes, for
// comparison.
import 'package:benchmark/src/load_app.dart';
import 'package:benchmark/src/serve.dart';
import 'package:benchmark/src/shelf_server.dart';

Future<void> main(List<String> args) async {
  final kind = args.isEmpty ? 'native' : args[0];
  final isolates = args.length < 2 ? 1 : int.parse(args[1]);
  final server = await startServer(
    kind,
    Served.app(loadApp(), shelfLoad),
    port: 18098,
    isolates: isolates,
  );
  await serveUntilSigterm(server);
}
