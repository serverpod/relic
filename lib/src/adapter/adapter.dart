import 'dart:async';

import '../hijack/hijack.dart';
import '../message/request.dart';
import '../message/response.dart';

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
