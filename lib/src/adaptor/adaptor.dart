import 'dart:async';

import '../message/request.dart';
import '../message/response.dart';

/// Base class for [Adaptor] specific requests.
///
/// This allow an [Adaptor] to track internal state across
/// requests, needed to
abstract class AdaptorRequest {
  /// Converts this adaptor-specific request into a standard [Request] object.
  Request toRequest();
}

/// Base class for all adaptors.
abstract class Adaptor {
  /// Stream of requests produced by this [Adaptor].
  Stream<AdaptorRequest> get requests;

  /// Respond to [request] with [response].
  Future<void> respond(final AdaptorRequest request, final Response response);

  /// Hijack [request], and let [callback] handle communication.
  Future<void> hijack(
      final AdaptorRequest request, final HijackCallback callback);

  /// Gracefully shuts down the adaptor, releasing any resources it holds.
  ///
  /// For example, for an HTTP server adaptor, this might close the underlying
  /// server socket.
  Future<void> close();
}
