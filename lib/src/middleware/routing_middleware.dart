import '../../relic.dart';

import '../router/normalized_path.dart';
import '../router/path_trie.dart';

final _routingContext = ContextProperty<
    ({
      Parameters parameters,
      NormalizedPath matched,
      NormalizedPath remaining
    })>();

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

extension RequestContextEx on RequestContext {
  NormalizedPath get matchedPath =>
      _routingContext.getOrNull(this)?.matched ?? NormalizedPath.empty;
  Map<Symbol, String> get pathParameters =>
      _routingContext.getOrNull(this)?.parameters ?? const <Symbol, String>{};
  NormalizedPath get remainingPath =>
      _routingContext.getOrNull(this)?.remaining ??
      NormalizedPath(Uri.decodeFull(request.url.path));
}

/// Extension to make [Router<Handler>] directly usable as a [Handler].
///
/// This allows a router to be used directly in a pipeline without wrapping it
/// with [routeWith].
///
/// Example:
/// ```dart
/// final router = Router<Handler>()
///   ..get('/users', usersHandler);
///
/// final handler = const Pipeline()
///     .addMiddleware(logRequests())
///     .addHandler(router.asHandler);
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
