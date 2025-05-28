import 'dart:async';

import 'package:stream_channel/stream_channel.dart';

import '../message/request.dart';
import '../message/response.dart';
import 'duplex_stream_channel.dart';

/// A callback function that handles a hijacked connection.
///
/// Hijacking allows low-level control of an HTTP connection, bypassing the normal
/// request-response lifecycle. This is often used for advanced use cases such as
/// upgrading the connection to WebSocket, custom streaming protocols, or raw data
/// processing.
///
/// Once a connection is hijacked, the server stops managing it, and the developer
/// gains direct access to the underlying socket or data stream.
typedef HijackCallback = void Function(StreamChannel<List<int>>);

/// Base class for adapter-specific request objects.
///
/// This allows an [Adapter] to encapsulate and track internal state
/// associated with an incoming request. Adapter-specific requests
/// can then be converted into a standard [Request] object for processing
/// by the application.
abstract class AdapterRequest {
  /// Converts this adapter-specific request into a standard [Request] object.
  ///
  /// This allows the core application logic to work with a consistent
  /// request model, abstracting away the details of the underlying adapter.
  Request toRequest();
}

/// An interface for adapters that bridge Relic to specific server implementations.
///
/// Adapters are responsible for receiving incoming requests from a source
/// (e.g., an HTTP server, a message queue), converting them into a standard
/// [AdapterRequest] format, and then handing them off to the Relic core.
/// They also handle sending back responses or managing hijacked connections.
abstract class Adapter {
  /// A stream of incoming requests from the underlying source.
  ///
  /// Each event in the stream is an [AdapterRequest] representing a new
  /// request that needs to be processed by the application.
  Stream<AdapterRequest> get requests;

  /// Sends a [Response] back to the client for the given [AdapterRequest].
  ///
  /// This method is called by the Relic core after a request has been processed
  /// and a response has been generated. The adapter is responsible for
  /// translating the standard [Response] object into the appropriate format
  /// for the underlying communication protocol.
  ///
  /// - [request]: The original [AdapterRequest] that this response corresponds to.
  /// - [response]: The [Response] to send.
  Future<void> respond(final AdapterRequest request, final Response response);

  /// Hijacks the connection associated with the [AdapterRequest].
  ///
  /// This passes control of the underlying communication channel (e.g., socket)
  /// to the provided [callback]. The callback receives a [StreamChannel]
  /// for direct, low-level interaction with the client.
  ///
  /// This is typically used for protocols like SSE or other custom
  /// streaming scenarios where the standard request-response model is
  /// insufficient.
  ///
  /// - [request]: The [AdapterRequest] whose connection is to be hijacked.
  /// - [callback]: The [HijackCallback] that will manage the hijacked
  /// connection.
  ///
  /// For web-sockets see [connect]
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

  /// Gracefully shuts down the adapter.
  ///
  /// This method should release any resources held by the adapter, such as
  /// closing server sockets or stopping listening for incoming requests.
  /// It ensures a clean termination of the adapter's operations.
  ///
  /// For example, for an HTTP server adapter, this might close the underlying
  /// server socket.
  Future<void> close();
}
