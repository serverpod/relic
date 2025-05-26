import 'dart:async';

import '../adapter/adapter.dart';
import '../adapter/context.dart';
import '../message/request.dart';
import '../message/response.dart';

/// A function that processes a [NewContext] to produce a [HandledContext].
///
/// For example, a static file handler may access the [Request] via the [NewContext],
/// read the requested URI from the filesystem, and return a [ResponseContext]
/// (a type of [HandledContext]) containing the file data as its body.
///
/// A function which produces a [Handler], either by wrapping one or more other handlers,
//  or using function composition is known as a "middleware".
///
/// A [Handler] may receive a [NewContext] directly from an HTTP server adapter or it
/// may have been processed by other middleware. Similarly, the resulting [HandledContext]
/// may be directly returned to an HTTP server adapter or have further processing
/// done by other middleware.
typedef Handler = FutureOr<HandledContext> Function(NewContext ctx);

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
/// the standard [Handler] format. The returned [Handler] takes a [NewContext],
/// retrieves its [Request] (which is passed to the [responder]), and then uses
/// the [Response] from the [responder] to create a [ResponseContext].
///
/// The input [NewContext] to the generated [Handler] must be a
/// [RespondableContext] (i.e., capable of producing a response) for the
/// `withResponse` call to succeed. The handler ensures the resulting context is
/// a [ResponseContext].
Handler respondWith(final Responder responder) {
  return (final ctx) async {
    return ctx.withResponse(await responder(ctx.request));
  };
}

/// Creates a [HijackHandler] that uses the given [HijackCallback] to
/// take control of the connection.
///
/// This adapts a [HijackCallback] into the [HijackHandler] format.
/// The returned handler takes a [HijackableContext], invokes the [callback]
/// to take control of the connection, and produces a [HijackContext].
HijackHandler hijack(final HijackCallback callback) {
  return (final ctx) {
    return ctx.hijack(callback);
  };
}
