import '../middleware/middleware.dart';
import 'handler.dart';

/// A helper that makes it easy to compose a set of [Middleware] and a
/// [Handler].
///
/// ```dart
///  var handler = const Pipeline()
///      .addMiddleware(loggingMiddleware)
///      .addMiddleware(cachingMiddleware)
///      .addHandler(application);
/// ```
///
/// Note: this package also provides `addMiddleware` and `addHandler` extensions
///  members on [Middleware], which may be easier to use.
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
