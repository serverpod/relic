import '../middleware/middleware.dart';
import 'handler.dart';

/// A helper that makes it easy to compose a set of [Middleware] and a
/// [Handler].
///
/// Middleware are executed in the order they are added, processing the request
/// top-down and the response bottom-up.
///
/// ## Basic Pipeline
///
/// ```dart
/// var handler = const Pipeline()
///     .addMiddleware(loggingMiddleware)
///     .addMiddleware(cachingMiddleware)
///     .addHandler(application);
/// ```
///
/// ## With Router
///
/// ```dart
/// final router = Router<Handler>();
/// router.get('/', homeHandler);
/// router.get('/api/users', usersHandler);
///
/// final handler = const Pipeline()
///     .addMiddleware(loggingMiddleware)
///     .addMiddleware(routeWith(router))
///     .addHandler(respondWith((_) => Response.notFound()));
/// ```
///
/// ## Execution Order
///
/// ```dart
/// // Request flows down:
/// // 1. Logging middleware (request)
/// // 2. Auth middleware (request)
/// // 3. Handler
/// // 4. Auth middleware (response)
/// // 5. Logging middleware (response)
///
/// final handler = const Pipeline()
///     .addMiddleware(loggingMiddleware)    // First to see request
///     .addMiddleware(authMiddleware)       // Second to see request
///     .addHandler(apiHandler);             // Last to process
/// ```
///
/// Note: this package also provides `addMiddleware` and `addHandler` extensions
/// members on [Middleware], which may be easier to use.
class Pipeline {
  /// Creates a new, empty pipeline.
  const Pipeline();

  /// Returns a new [Pipeline] with [middleware] added to the existing set of
  /// [Middleware].
  ///
  /// [middleware] will be the last [Middleware] to process a request and
  /// the first to process a response.
  Pipeline addMiddleware(final Middleware middleware) =>
      _Pipeline(middleware, addHandler);

  /// Returns a new [Handler] with [handler] as the final processor of a
  /// [Request] if all of the middleware in the pipeline have passed the request
  /// through.
  Handler addHandler(final Handler handler) => handler;

  /// Exposes this pipeline of [Middleware] as a single middleware instance.
  Middleware get middleware => addHandler;
}

class _Pipeline extends Pipeline {
  final Middleware _middleware;
  final Middleware _parent;

  const _Pipeline(this._middleware, this._parent);

  @override
  Handler addHandler(final Handler handler) => _parent(_middleware(handler));
}
