import 'dart:async';

import '../message/request.dart';
import '../message/response.dart';

/// An abstraction for the context of a request.
abstract class RequestContext {
  Request get request;
  Future<void> respond(final Response response);
}

/// An abstraction for adaptors that can produce HTTP requests and consume responses.
abstract class Adaptor {
  /// The producer of [requests].
  ///
  /// For each request a [Response] must be produced and passed to this
  /// adaptor
  ///
  /// The request may be is accompanied by an adaptor specific [context]. If so, it
  /// must be passed back along with the response.
  Stream<RequestContext> get requests;

  /// Gracefully close this [Adaptor].
  Future<void> close();
}
