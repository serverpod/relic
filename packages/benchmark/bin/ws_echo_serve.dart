// A WebSocket echo server for a load tool started elsewhere, such as
// uWebSockets' load_test. Echoes every message on port 18098 until
// SIGTERM.
//
//   dart run bin/ws_echo_serve.dart native   # or: io, shelf
import 'package:benchmark/src/echo_web_socket.dart';
import 'package:benchmark/src/serve.dart';
import 'package:benchmark/src/shelf_server.dart';

Future<void> main(final List<String> args) async {
  final kind = args.isEmpty ? 'native' : args[0];
  final server = await startServer(
    kind,
    Served.handler(echoWebSocket, shelfWebSocketEcho),
    port: 18098,
  );
  await serveUntilSigterm(server);
}
