import 'dart:async';

import '../adapter/adapter.dart';
import '../context/context.dart';
import '../router/method.dart';
import '../router/router.dart';

/// A function that processes a [Request] to produce a [HandledContext].
///
/// For example, a static file handler may access the [Request] via the [Request],
/// read the requested URI from the filesystem, and return a [ResponseContext]
/// (a type of [HandledContext]) containing the file data as its body.
///
/// A function which produces a [Handler], either by wrapping one or more other handlers,
/// or using function composition is known as a "middleware".
///
/// A [Handler] may receive a [Request] directly from an HTTP server adapter or it
/// may have been processed by other middleware. Similarly, the resulting [HandledContext]
/// may be directly returned to an HTTP server adapter or have further processing
/// done by other middleware.
///
/// ## Basic Handler
///
/// ```dart
/// ResponseContext myHandler(RequestContext ctx) {
///   return ctx.respond(
///     Response.ok(
///       body: Body.fromString('Hello, World!'),
///     ),
///   );
/// };
/// ```
///
/// ## Async Handler
///
/// ```dart
/// Future<ResponseContext> asyncHandler(RequestContext ctx) async {
///   final data = await fetchDataFromDatabase();
///   return ctx.respond(
///     Response.ok(
///       body: Body.fromString(jsonEncode(data), mimeType: MimeType.json),
///     ),
///   );
/// };
/// ```
///
/// ## Handler with Path Parameters
///
/// ```dart
/// // Route: /users/:id
/// Handler userHandler(RequestContext ctx) {
///   final id = ctx.pathParameters[#id];
///   return ctx.respond(
///     Response.ok(
///       body: Body.fromString('User ID: $id'),
///     ),
///   );
/// };
/// ```
typedef Handler = FutureOr<HandledContext> Function(Request req);

/// A handler specifically designed to produce a [ResponseContext].
///
/// It takes a [RespondableContext] and must return a [FutureOr<ResponseContext>].
/// This is useful for handlers that are guaranteed to generate a response.
typedef ResponseHandler =
    FutureOr<ResponseContext> Function(RespondableContext ctx);

/// A handler specifically designed to produce a [HijackedContext].
///
/// It takes a [HijackableContext] and must return a [FutureOr<HijackedContext>].
/// This is useful for handlers that are guaranteed to hijack the connection
/// (e.g., for WebSocket upgrades).
typedef HijackHandler =
    FutureOr<HijackedContext> Function(HijackableContext ctx);

/// A function which handles exceptions.
///
/// This typedef is used to define how exceptions should be handled in the
/// context of processing requests. It takes in the [error] and [stackTrace]
/// and returns a [Response] after processing the exception.
typedef ExceptionHandler =
    FutureOr<Response> Function(Object error, StackTrace stackTrace);

/// A simplified handler function that takes a [Request] and returns a [Response].
///
/// This is often used with helper functions like [respondWith] to create
/// standard [Handler] instances more easily.
typedef Responder = FutureOr<Response> Function(Request);

/// Creates a [Handler] that uses the given [Responder] function to generate
/// a response.
///
/// This adapts a simpler `Request -> Response` function ([Responder]) into
/// the standard [Handler] format. The returned [Handler] takes a [Request],
/// retrieves its [Request] (which is passed to the [responder]), and then uses
/// the [Response] from the [responder] to create a [ResponseContext].
///
/// The input [Request] to the generated [Handler] must be a
/// [RespondableContext] (i.e., capable of producing a response) for the
/// `respond` call to succeed. The handler ensures the resulting context is
/// a [ResponseContext].
///
/// Example:
/// ```dart
/// final handler = respondWith(
///   (final request) => Response.ok(
///     body: Body.fromString('Hello, Relic!'),
///   ),
/// );
/// ```
Handler respondWith(final Responder responder) {
  return (final ctx) async {
    return await responder(ctx);
  };
}

/// Creates a [HijackHandler] that uses the given [HijackCallback] to
/// take control of the connection.
///
/// This adapts a [HijackCallback] into the [HijackHandler] format.
/// The returned handler takes a [HijackableContext], invokes the [callback]
/// to take control of the connection, and produces a [HijackedContext].
HijackHandler hijack(final HijackCallback callback) {
  return (final ctx) {
    return ctx.hijack(callback);
  };
}

/// An abstract base class for classes that behave like [Handler]s.
///
/// Instances of [HandlerObject] are callable as [Handlers], and
/// can be passed as handlers via a [call] tear-off.
///
/// Overriding [call] is mandatory.
///
/// If the handler requires special path parameters, or supports other
/// methods than [Method.get], then you should override [injectIn].
abstract class HandlerObject implements RouterInjectable {
  /// Adds this handler to the given [router] with [Method.get] and path '/'
  /// Override to add differently.
  @override
  void injectIn(final RelicRouter router) => router.get('/', call);

  /// The implementation of this [HandlerObject]
  FutureOr<HandledContext> call(final Request req);

  /// Returns this [HandlerObject] as a [Handler].
  Handler get asHandler => call;

  const HandlerObject();
}
