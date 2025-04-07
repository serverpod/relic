import 'dart:async';

import '../message/request.dart';
import '../message/response.dart';
import 'adaptor.dart';

/// An abstraction for the context of a request.
abstract class RequestContext {
  Request get request;
  Future<void> respond(final Response response);
}

/// An abstraction for adaptors that can produce HTTP requests and consume responses.
abstract class ServerAdaptor {
  /// The producer of [requests].
  ///
  /// For each request a [Response] must be produced and passed to the
  /// [responses] consumer.
  ///
  /// The request may be is accompanied by an adaptor specific [context]. If so, it
  /// must be passed back along with the response.
  Stream<RequestContext> get requests;

  /// Address information (platform agnostic)
  Address get address;

  /// Port the server is listening on
  int get port;
}
