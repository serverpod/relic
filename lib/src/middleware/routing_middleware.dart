import '../adapter/context.dart';
import '../handler/handler.dart';
import '../method/request_method.dart';
import '../router/lookup_result.dart';
import '../router/method.dart';
import '../router/normalized_path.dart';
import '../router/path_trie.dart';
import '../router/router.dart';
import 'context_property.dart';
import 'middleware.dart';

Middleware routeWith<T>(
  final Router<T> router, {
  final Handler Function(T)? toHandler,
}) =>
    _RoutingMiddlewareBuilder(router, toHandler: toHandler).build();

final _routingContext = ContextProperty<
    ({
      Parameters parameters,
      NormalizedPath matched,
      NormalizedPath remaining
    })>();

class _RoutingMiddlewareBuilder<T> {
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

  Handler _meddle(final Handler next) {
    return (final ctx) async {
      final req = ctx.request;
      final path = Uri.decodeFull(req.url.path);
      final match = _router.lookup(req.method.convert(), path);
      if (match is RouterMatch<T>) {
        _routingContext[ctx] = (
          parameters: match.parameters,
          matched: match.matched,
          remaining: match.remaining,
        );
        final handler = _toHandler(match.value);
        return await handler(ctx);
      } else {
        return await next(ctx);
      }
    };
  }

  Middleware build() => _meddle;
}

extension RequestContextEx on RequestContext {
  Map<Symbol, String> get pathParameters =>
      _routingContext.getOrNull(this)?.parameters ?? const <Symbol, String>{};
  NormalizedPath get matchedPath =>
      _routingContext.getOrNull(this)?.matched ?? NormalizedPath.empty;
  NormalizedPath get remainingPath =>
      _routingContext.getOrNull(this)?.remaining ??
      NormalizedPath(Uri.decodeFull(request.url.path));
}

bool _isSubtype<S, T>() => <S>[] is List<T>;

extension on RequestMethod {
  Method convert() {
    return switch (this) {
      RequestMethod.get => Method.get,
      RequestMethod.post => Method.post,
      RequestMethod.put => Method.put,
      RequestMethod.delete => Method.delete,
      RequestMethod.head => Method.head,
      RequestMethod.options => Method.options,
      RequestMethod.patch => Method.patch,
      RequestMethod.trace => Method.trace,
      RequestMethod.connect => Method.connect,
    };
  }
}
