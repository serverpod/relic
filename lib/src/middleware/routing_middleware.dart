import '../../relic.dart';

import '../router/normalized_path.dart';
import '../router/path_trie.dart';

final _routingContext =
    ContextProperty<
      ({
        Parameters parameters,
        NormalizedPath matched,
        NormalizedPath remaining,
      })
    >();

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
/// are accessible via [RequestEx] extensions on the context passed to
/// handlers.
///
/// **Note:** For [RelicRouter], prefer using [Router.use] for middleware
/// composition, [Router.fallback] for 404 handling, and [RouterHandlerEx.asHandler]
/// to use the router directly as a handler. This avoids the need for
/// [Pipeline] and provides better composability.
///
/// Preferred approach:
/// ```dart
/// final router = RelicRouter()
///   ..get('/users/:id', userHandler)
///   ..use('/', logRequests())
///   ..fallback = notFoundHandler;
///
/// await serve(router.asHandler, ...);
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
}) => _RoutingMiddlewareBuilder(router, toHandler: toHandler).asMiddleware;

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

  Middleware get asMiddleware => call;

  Handler call(final Handler next) {
    return (final req) async {
      final path = Uri.decodeFull(req.requestedUri.path);
      final result = _router.lookup(req.method, path);
      switch (result) {
        case MethodMiss():
          return Response(
            405,
            headers: Headers.build((final mh) => mh.allow = result.allowed),
          );
        case PathMiss():
          return await next(req);
        case final RouterMatch<T> match:
          _routingContext[req] = (
            parameters: match.parameters,
            matched: match.matched,
            remaining: match.remaining,
          );
          final handler = _toHandler(match.value);
          return await handler(req);
      }
    };
  }
}

/// Extension on [Request] providing access to routing information.
///
/// These properties are populated when a request is routed using [routeWith]
/// or [RouterHandlerEx.asHandler], and are available to all handlers in the processing
/// chain.
extension RoutingRequestEx on Request {
  /// The portion of the request path that was matched by the route.
  ///
  /// For example, if the route pattern is `/api/**` and the request is to
  /// `/api/users/123`, this returns `/api`. For exact matches, this is the
  /// entire path.
  ///
  /// This replaces the deprecated `handlerPath` property from earlier versions.
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
  /// router.get('/users/:id', (req) {
  ///   final id = req.pathParameters[#id]; // Extract 'id' parameter
  ///   return Response.ok();
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
      NormalizedPath(Uri.decodeFull(requestedUri.path));
}
