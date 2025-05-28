import 'dart:async';
import 'dart:typed_data';
import 'package:stream_channel/stream_channel.dart';

/// An abstract class representing a bi-directional communication channel.
///
/// This class mixes in [StreamChannelMixin] and implements [StreamChannel]
/// for [Payload] types. It defines a common interface for duplex streams,
/// such as WebSockets, allowing for sending and receiving [Payload] messages.
abstract class DuplexStreamChannel
    with StreamChannelMixin<Payload>
    implements StreamChannel<Payload> {
  /// The interval at which ping messages are sent to keep the connection alive.
  ///
  /// If null, no ping messages are sent.
  Duration? pingInterval;

  /// Closes the duplex stream channel.
  ///
  /// Implementations should gracefully terminate the connection.
  /// Optionally, a [closeCode] and [closeReason] can be provided,
  /// which may be used by the underlying protocol (e.g., WebSocket close frames).
  Future<void> close([final int? closeCode, final String? closeReason]);
}

/// A sealed class representing the types of messages that can be sent or received
/// over a [DuplexStreamChannel].
///
/// This allows for type-safe handling of different message formats,
/// like binary or text.
sealed class Payload {
  const Payload();
}

/// A [Payload] representing a binary message.
///
/// Contains raw byte data.
final class BinaryPayload extends Payload {
  /// The binary data of this payload.
  final Uint8List data;

  /// Creates a new [BinaryPayload] with the given [data].
  const BinaryPayload(this.data);
}

/// A [Payload] representing a text message.
///
/// Contains string data.
final class TextPayload extends Payload {
  /// The text data of this payload.
  final String data;

  /// Creates a new [TextPayload] with the given [data].
  const TextPayload(this.data);
}

/// A callback function that handles a [DuplexStreamChannel].
///
/// This is typically used when a connection is established (e.g., a WebSocket
/// connection), providing the handler with the channel to manage communication.
typedef DuplexStreamCallback = void Function(DuplexStreamChannel channel);
