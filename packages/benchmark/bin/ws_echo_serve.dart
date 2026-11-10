// A WebSocket echo server for a load tool started elsewhere, such as
// uWebSockets' load_test. Echoes every message on port 18098 until
// SIGTERM, over TLS with the test certificates when the second argument
// is `tls`.
//
//   dart run bin/ws_echo_serve.dart native   # or: io, shelf
//   dart run bin/ws_echo_serve.dart native tls
import 'package:benchmark/src/echo_web_socket.dart';
import 'package:benchmark/src/serve.dart';
import 'package:benchmark/src/shelf_server.dart';

Future<void> main(List<String> args) async {
  final kind = args.isEmpty ? 'native' : args[0];
  final tls = args.length > 1 && args[1] == 'tls';
  final server = await startServer(
    kind,
    Served.handler(echoWebSocket, shelfWebSocketEcho),
    port: 18098,
    tls: tls,
  );
  await serveUntilSigterm(server);
}
