import 'dart:async';

import '../adapter/adapter.dart';
import '../adapter/context.dart';
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

/// A handler specifically designed to produce a [ResponseContext].
///
/// It takes a [RespondableContext] and must return a [FutureOr<ResponseContext>].
/// This is useful for handlers that are guaranteed to generate a response.
typedef ResponseHandler = FutureOr<ResponseContext> Function(
    RespondableContext ctx);

/// A handler specifically designed to produce a [HijackContext].
///
/// It takes a [HijackableContext] and must return a [FutureOr<HijackContext>].
/// This is useful for handlers that are guaranteed to hijack the connection
/// (e.g., for WebSocket upgrades).
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

/// A simplified handler function that takes a [Request] and returns a [Response].
///
/// This is often used with helper functions like [respondWith] to create
/// standard [Handler] instances more easily.
typedef Responder = FutureOr<Response> Function(Request);

/// Creates a [Handler] that uses the given [Responder] function to generate
/// a response.
///
/// This adapts a simpler `Request -> Response` function ([Responder]) into
/// the standard [Handler] format, which operates on [RequestContext].
/// It ensures the resulting context is a [ResponseContext].
/// Throws an [ArgumentError] if the incoming context is not [RespondableContext].
Handler respondWith(final Responder responder) {
  return (final ctx) async {
    return switch (ctx) {
      final RespondableContext rc =>
        rc.withResponse(await responder(rc.request)),
      _ => throw ArgumentError(ctx.runtimeType),
    };
  };
}

/// Creates a [HijackHandler] that uses the given [HijackCallback] to
/// take control of the connection.
///
/// This adapts a [HijackCallback] into the [HijackHandler] format,
/// which operates on [RequestContext]. It ensures the resulting context
/// is a [HijackContext].
HijackHandler hijack(final HijackCallback callback) {
  return (final ctx) {
    return ctx.hijack(callback);
  };
}
