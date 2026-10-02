import 'dart:typed_data';

import 'package:web_socket/web_socket.dart';

/// An relic specific interface for bi-directional communication over
/// web-sockets.
abstract interface class RelicWebSocket implements WebSocket {
  /// The interval at which ping frames are sent to keep the web-socket
  /// connection alive.
  ///
  /// If `null`, no ping messages are sent.
  Duration? pingInterval;

  /// Completes once the connection is closed, whoever closed it.
  ///
  /// Never completes with an error.
  Future<void> get done;

  /// Whether the web-socket is closed.
  ///
  /// May return false positives (`true`), if the peer is disconnected but the
  /// disconnect has not yet been detected.
  bool get isClosed;

  /// Sends text data to the peer, unless connection is already
  /// closed (either through [close] or by the peer). Returns `false` if
  /// connection is known to be closed, otherwise `true`.
  ///
  /// Data sent through [sendText] will be silently discarded if the peer is
  /// disconnected but the disconnect has not yet been detected.
  bool trySendText(String s);

  /// Sends binary data to the peer, unless connection is already
  /// closed (either through [close] or by the peer). Returns `false` if
  /// connection is known to be closed, otherwise `true`.
  ///
  /// Data sent through [sendBytes] will be silently discarded if the peer is
  /// disconnected but the disconnect has not yet been detected.
  bool trySendBytes(Uint8List b);

  /// Try to close the WebSocket connection and the [events] `Stream`.
  ///
  /// Returns `false` if already closed (including by peer), otherwise sends
  /// a Close frame to the peer and returns `true`. If the optional [code] and
  /// [reason] arguments are given, they will be included in the Close frame. If no
  /// [code] is set then the peer will see a 1005 status code. If no [reason]
  /// is set then the peer will not receive a reason string.
  ///
  /// Throws an [ArgumentError] if [code] is not 1000 or in the range 3000-4999.
  ///
  /// Throws an [ArgumentError] if [reason] is longer than 123 bytes when
  /// encoded as UTF-8
  Future<bool> tryClose([int? code, String? reason]);

  /// Tells the peer the server is going away (RFC 6455 1001) and waits,
  /// within a bound, for the connection to end.
  ///
  /// For the server on shutdown. Does nothing on a closed socket. Never
  /// throws.
  Future<void> closeGoingAway();
}

/// A callback function invoked when a [socket] connection is established.
typedef WebSocketCallback = void Function(RelicWebSocket webSocket);
