import '../../relic.dart';

import '../router/normalized_path.dart';
import '../router/path_trie.dart';

final _routingContext = ContextProperty<
    ({
      Parameters parameters,
      NormalizedPath matched,
      NormalizedPath remaining
    })>();

/// Creates middleware that routes requests using the provided [router].
///
/// This function converts a [Router] into middleware that can be used in a
/// [Pipeline]. When a request matches a route, the associated value is
/// converted to a [Handler] and invoked. If no route matches (path miss),
/// the next handler in the pipeline is called. If the path matches but the
/// method doesn't (method miss), a 405 response is returned with the Allow
/// header listing supported methods.
///
/// Path parameters, matched path, and remaining path from the routing lookup
/// are accessible via [RequestContextEx] extensions on the context passed to
/// handlers.
///
/// **Note:** For [Router<Handler>], prefer using [Router.use] for middleware
/// composition, [Router.fallback] for 404 handling, and [RouterHandler.call]
/// to use the router directly as a handler. This avoids the need for
/// [Pipeline] and provides better composability.
///
/// Preferred approach:
/// ```dart
/// final router = Router<Handler>()
///   ..get('/users/:id', userHandler)
///   ..use('/', logRequests())
///   ..fallback = notFoundHandler;
///
/// await serve(router.call, ...);
/// ```
///
/// This function is primarily useful for [Router<T>] where `T` is not
/// [Handler], requiring conversion via [toHandler]:
///
/// ```dart
/// final router = Router<String>()
///   ..get('/hello', 'Hello World');
///
/// final handler = const Pipeline()
///     .addMiddleware(routeWith(
///       router,
///       toHandler: (message) => respondWith(
///         (_) => Response.ok(body: Body.fromString(message))
///       ),
///     ))
///     .addHandler(notFoundHandler);
/// ```
Middleware routeWith<T extends Object>(
  final Router<T> router, {
  final Handler Function(T)? toHandler,
}) =>
    _RoutingMiddlewareBuilder(router, toHandler: toHandler).build();

bool _isSubtype<S, T>() => <S>[] is List<T>;

class _RoutingMiddlewareBuilder<T extends Object> {
  final Router<T> _router;
  late final Handler Function(T) _toHandler;

  _RoutingMiddlewareBuilder(
    this._router, {
    final Handler Function(T)? toHandler,
  }) {
    if (toHandler != null) {
      _toHandler = toHandler;
    } else if (_isSubtype<T, Handler>()) {
      _toHandler = (final x) => x as Handler;
    }
    ArgumentError.checkNotNull(_toHandler, 'toHandler');
  }

  Middleware build() => _meddle;

  Handler _meddle(final Handler next) {
    return (final ctx) async {
      final req = ctx.request;
      final path = Uri.decodeFull(req.url.path);
      final result = _router.lookup(req.method, path);
      switch (result) {
        case MethodMiss():
          return ctx.respond(Response(405,
              headers: Headers.build((final mh) => mh.allow = result.allowed)));
        case PathMiss():
          return await next(ctx);
        case final RouterMatch<T> match:
          _routingContext[ctx] = (
            parameters: match.parameters,
            matched: match.matched,
            remaining: match.remaining,
          );
          final handler = _toHandler(match.value);
          return await handler(ctx);
      }
    };
  }
}

/// Extension on [RequestContext] providing access to routing information.
///
/// These properties are populated when a request is routed using [routeWith]
/// or [RouterHandler.call], and are available to all handlers in the processing
/// chain.
extension RequestContextEx on RequestContext {
  /// The portion of the request path that was matched by the route.
  ///
  /// For example, if the route pattern is `/api/**` and the request is to
  /// `/api/users/123`, this returns `/api`. For exact matches, this is the
  /// entire path.
  ///
  /// Returns [NormalizedPath.empty] if the request was not routed through
  /// a router.
  NormalizedPath get matchedPath =>
      _routingContext.getOrNull(this)?.matched ?? NormalizedPath.empty;

  /// Path parameters extracted from the matched route.
  ///
  /// Parameters are defined in route patterns using `:` prefix (e.g., `:id`).
  /// The map keys are [Symbol]s of the parameter names, and values are the
  /// extracted strings from the request path.
  ///
  /// Example:
  /// ```dart
  /// router.get('/users/:id', (ctx) {
  ///   final id = ctx.pathParameters[#id]; // Extract 'id' parameter
  ///   return ctx.respond(Response.ok());
  /// });
  /// ```
  ///
  /// Returns an empty map if no parameters were extracted or if the request
  /// was not routed through a router.
  Map<Symbol, String> get pathParameters =>
      _routingContext.getOrNull(this)?.parameters ?? const <Symbol, String>{};

  /// The portion of the request path that was not consumed by the matched route.
  ///
  /// This is primarily useful with tail segment routes (those ending with `/**`).
  /// For example, if the route pattern is `/static/**` and the request is to
  /// `/static/css/main.css`, this returns `/css/main.css`.
  ///
  /// For routes without tail segments, this is typically empty. If the request
  /// was not routed through a router, this returns the full request path.
  NormalizedPath get remainingPath =>
      _routingContext.getOrNull(this)?.remaining ??
      NormalizedPath(Uri.decodeFull(request.url.path));
}

/// Extension to make [Router<Handler>] directly usable as a [Handler].
///
/// This extension allows [Router<Handler>] to be used as a handler without
/// wrapping it with [routeWith]. Compose middleware using [Router.use] and
/// handle 404s using [Router.fallback] instead of Pipeline and Cascade.
///
/// Example:
/// ```dart
/// final router = Router<Handler>()
///   ..get('/users/:id', usersHandler)
///   ..use('/', logRequests())
///   ..fallback = notFoundHandler;
///
/// await serve(router.asHandler, InternetAddress.anyIPv4, 8080);
/// ```
extension RouterHandler on Router<Handler> {
  /// Makes [Router<Handler>] callable as a [Handler].
  ///
  /// Performs routing lookup and:
  /// - Returns 405 if path matches but method doesn't (with Allow header)
  /// - Calls fallback handler if set and no route matches
  /// - Returns 404 if no fallback is set and no route matches
  /// - Calls the matched handler if route is found
  ///
  /// Path parameters, matched path, and remaining path are accessible via
  /// [RequestContextEx] extensions on the context passed to handlers.
  Handler get asHandler => const Pipeline()
      .addMiddleware(routeWith(this))
      .addHandler(fallback ?? respondWith((final _) => Response.notFound()));
}
