import 'package:relic/relic.dart';
import 'package:web_socket/web_socket.dart'
    show BinaryDataReceived, CloseReceived, TextDataReceived;

/// Upgrades every request to a WebSocket that sends each message back, as
/// bin/ws_echo.dart and bin/ws_echo_serve.dart serve it.
WebSocketUpgrade echoWebSocket(Request req) => WebSocketUpgrade((ws) {
  ws.events.listen((event) {
    switch (event) {
      case TextDataReceived(:final text):
        ws.trySendText(text);
      case BinaryDataReceived(:final data):
        ws.trySendBytes(data);
      case CloseReceived():
        break;
    }
  });
});
