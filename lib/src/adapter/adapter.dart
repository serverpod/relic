import 'dart:async';
import 'dart:typed_data';

import 'package:stream_channel/stream_channel.dart';

import '../message/request.dart';
import '../message/response.dart';

/// Hijacking allows low-level control of an HTTP connection, bypassing the normal
/// request-response lifecycle. This is often used for advanced use cases such as
/// upgrading the connection to WebSocket, custom streaming protocols, or raw data
/// processing.
///
/// Once a connection is hijacked, the server stops managing it, and the developer
/// gains direct access to the underlying socket or data stream.
typedef HijackCallback = void Function(StreamChannel<List<int>>);

sealed class Payload {
  const Payload();
}

final class BinaryPayload extends Payload {
  final Uint8List data;
  const BinaryPayload(this.data);
}

final class TextPayload extends Payload {
  final String data;
  const TextPayload(this.data);
}

abstract class DuplexStreamChannel
    with StreamChannelMixin<Payload>
    implements StreamChannel<Payload> {
  Future<void> close([final int? closeCode, final String? closeReason]);
}

typedef DuplexStreamCallback = void Function(DuplexStreamChannel);

/// Base class for [Adapter] specific requests.
///
/// This allow an [Adapter] to track internal state across
/// requests, needed to
abstract class AdapterRequest {
  /// Converts this adapter-specific request into a standard [Request] object.
  Request toRequest();
}

/// Base class for all adapters.
abstract class Adapter {
  /// Stream of requests produced by this [Adapter].
  Stream<AdapterRequest> get requests;

  /// Respond to [request] with [response].
  Future<void> respond(final AdapterRequest request, final Response response);

  /// Hijack [request], and let [callback] handle communication.
  Future<void> hijack(
      final AdapterRequest request, final HijackCallback callback);

  /// Establishes a duplex stream connection (e.g., WebSocket) for the given
  /// [AdapterRequest].
  ///
  /// This method is used to upgrade a connection or establish a new
  /// bi-directional communication channel. The provided [wsCallback] will
  /// be invoked with a [DuplexStreamChannel] that allows sending and
  /// receiving [Payload] messages.
  ///
  /// - [request]: The [AdapterRequest] for which to establish the connection.
  /// - [wsCallback]: The [DuplexStreamCallback] that will handle the duplex
  /// stream.
  Future<void> connect(
      final AdapterRequest request, final DuplexStreamCallback wsCallback);

  /// Gracefully shuts down the adapter, releasing any resources it holds.
  ///
  /// For example, for an HTTP server adapter, this might close the underlying
  /// server socket.
  Future<void> close();
}
