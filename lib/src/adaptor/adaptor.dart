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
  Stream<RequestContext> get requests;

  /// Gracefully close this [Adaptor].
  Future<void> close();
}
