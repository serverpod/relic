import 'dart:async';

import '../context/context.dart';
import '../router/method.dart';
import '../router/router.dart';

/// A function that processes a [Request] to produce a [Result].
///
/// For example, a static file handler may extract the requested URI from the
/// [Request], read the corresponding file from the filesystem, and return a
/// [Response] containing the file data as its [Body].
///
/// A function which produces a [Handler], either by wrapping one or more other handlers,
/// or using function composition is known as a "middleware".
///
/// A [Handler] may receive a [Request] directly from an HTTP server adapter or it
/// may have been processed by other middleware. Similarly, the resulting [Result]
/// may be directly returned to an HTTP server adapter or have further processing
/// done by other middleware.
///
/// ## Basic Handler
///
/// ```dart
/// Response myHandler(Request req) {
///   return Response.ok(
///     body: Body.fromString('Hello, World!'),
///   );
/// }
/// ```
///
/// ## Async Handler
///
/// ```dart
/// Future<Response> asyncHandler(Request req) async {
///   final data = await fetchDataFromDatabase();
///   return Response.ok(
///     body: Body.fromString(jsonEncode(data), mimeType: MimeType.json),
///   );
/// }
/// ```
///
/// ## Handler with Path Parameters
///
/// ```dart
/// // Route: /users/:id
/// Handler userHandler(Request req) {
///   final id = req.pathParameters[#id];
///   return Response.ok(
///     body: Body.fromString('User ID: $id'),
///   );
/// }
/// ```
typedef Handler = FutureOr<Result> Function(Request req);

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
/// passes it to the [responder], and returns the resulting [Response].
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
  return (final req) async {
    return await responder(req);
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
  FutureOr<Result> call(final Request req);

  /// Returns this [HandlerObject] as a [Handler].
  Handler get asHandler => call;

  const HandlerObject();
}
