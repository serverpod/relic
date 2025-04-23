import 'dart:async';

import '../adaptor/context.dart';
import '../message/request.dart';
import '../message/response.dart';

/// A function which handles a [Request].
///
/// For example, a static file handler may read the requested URI from the
/// filesystem and return it as the body of the [Response].
///
/// A [Handler] which wraps one or more other handlers to perform pre or post
/// processing is known as a "middleware".
///
/// A [Handler] may receive a request directly from an HTTP server or it
/// may have been touched by other middleware. Similarly, the response may be
/// directly returned by an HTTP server or have further processing done by other
/// middleware.
typedef Handler = FutureOr<RequestContext> Function(RequestContext ctx);

typedef ResponseHandler = FutureOr<ResponseContext> Function(
    RespondableContext ctx);

typedef HijackHandler = FutureOr<HijackContext> Function(HijackableContext ctx);

/// A function which handles exceptions.
///
/// This typedef is used to define how exceptions should be handled in the
/// context of processing requests. It takes in the [error] and [stackTrace]
/// and returns a [Response] after processing the exception.
typedef ExceptionHandler = FutureOr<Response> Function(
  Object error,
  StackTrace stackTrace,
);

typedef Responder = FutureOr<Response> Function(Request);

Handler respondWith(final Responder responder) {
  return (final ctx) async {
    return switch (ctx) {
      final RespondableContext rc =>
        rc.withResponse(await responder(rc.request)),
      _ => throw ArgumentError(ctx.runtimeType),
    };
  };
}

HijackHandler hijack(final HijackCallback callback) {
  return (final ctx) {
    return ctx.hijack(callback);
  };
}
