import 'package:web_socket/web_socket.dart';

/// An relic specific interface for bi-directional communication over
/// web-sockets.
///
/// Extends [WebSocket] with [pingInterval] property for configuring
/// ping/pong frame timeout.
abstract interface class RelicWebSocket implements WebSocket {
  /// The interval at which ping frames are sent to keep the web-socker
  /// connection alive.
  ///
  /// If `null`, no ping messages are sent.
  Duration? pingInterval;
}

/// A callback function invoked when a [socket] connection is established.
typedef WebSocketCallback = void Function(RelicWebSocket webSocket);
