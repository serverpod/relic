import 'dart:async';

import 'package:stream_channel/stream_channel.dart';

import '../message/response.dart';
import 'context.dart';
import 'ip_address.dart';
import 'relic_web_socket.dart';

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

/// Interface for adapter-specific request objects.
///
/// This allows an [Adapter] to encapsulate and track internal state
/// associated with an incoming request. Adapter-specific requests
/// can then be converted into a standard [RequestContext] object for processing
/// by the application.
abstract interface class AdapterRequest {}

/// An interface for adapters that bridge Relic to specific server implementations.
///
/// Adapters are responsible for receiving incoming requests from a source
/// (e.g., an HTTP server, a message queue), converting them into a standard
/// [AdapterRequest] format, and then handing them off to the Relic core.
/// They also handle sending back responses or managing hijacked connections.
abstract class Adapter {
  /// The [IPAddress] the underlying server is listening on.
  IPAddress get address;

  /// The port number the underlying server is listening on.
  int get port;

  /// A stream of incoming requests from the underlying source.
  ///
  /// Each event in the stream is an [AdapterRequest] representing a new
  /// request that needs to be processed by the application.
  Stream<AdapterRequest> get requests;

  /// Converts an [AdapterRequest] into a [NewContext].
  ///
  /// This method is called by the Relic core when a new request is received.
  /// The adapter is responsible for translating the [request]
  /// into a [NewContext] that can be used by the application.
  NewContext convert(final AdapterRequest request);

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
  /// This is typically used for protocols like SSE or to support custom
  /// streaming scenarios where the standard request-response model, or
  /// web-socket communication is insufficient.
  ///
  /// - [request]: The [AdapterRequest] whose connection is to be hijacked.
  /// - [callback]: The [HijackCallback] that will manage the hijacked
  /// connection.
  ///
  /// For web-sockets see [connect]
  Future<void> hijack(
      final AdapterRequest request, final HijackCallback callback);

  /// Establishes a web-socket connection for the given [AdapterRequest].
  ///
  /// The provided [callback] will be invoked with a [RelicWebSocket] that
  /// allows sending and receiving messages the web-socket connection.
  ///
  /// - [request]: The [AdapterRequest] for which to establish the connection.
  /// - [callback]: The [WebSocketCallback] that will be invoked on inbound
  ///   connection requests.
  Future<void> connect(
      final AdapterRequest request, final WebSocketCallback callback);

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
