import 'dart:async';

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

  /// Gracefully shuts down the adapter, releasing any resources it holds.
  ///
  /// For example, for an HTTP server adapter, this might close the underlying
  /// server socket.
  Future<void> close();
}
