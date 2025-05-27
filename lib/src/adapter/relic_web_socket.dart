import 'package:stream_channel/stream_channel.dart';
import 'package:web_socket/web_socket.dart';

/// An abstract class representing a bi-directional communication channel.
///
/// This class mixes in [StreamChannelMixin] and implements [StreamChannel]
/// for [Payload] types. It defines a common interface for duplex streams,
/// such as WebSockets, allowing for sending and receiving [Payload] messages.
abstract class RelicWebSocket implements WebSocket {
  /// The interval at which ping messages are sent to keep the connection alive.
  ///
  /// If null, no ping messages are sent.
  Duration? pingInterval;

  Future<void> flush();
}

/// A callback function that handles a [RelicWebSocket].
///
/// This is typically used when a connection is established (e.g., a WebSocket
/// connection), providing the handler with the channel to manage communication.
typedef WebSocketCallback = void Function(RelicWebSocket channel);
