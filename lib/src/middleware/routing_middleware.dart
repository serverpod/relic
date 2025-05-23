import '../adapter/context.dart';
import '../handler/handler.dart';
import '../method/request_method.dart';
import '../router/router.dart';
import 'middleware.dart';

Middleware routeWith<T>(
  final Router<T> router, {
  final Handler Function(T)? toHandler,
}) =>
    _RoutingMiddlewareBuilder(router, toHandler: toHandler).build();

final _pathParametersStorage = Expando<Map<Symbol, String>>();

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
      final url = ctx.request.url; // TODO: Use requestUri
      final match = _router.lookup(req.method.convert(), url.path);
      if (match != null) {
        ctx._pathParameters = match.parameters;
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
      _pathParametersStorage[token] ??
      (throw StateError('Add RoutingMiddleware!'));

  set _pathParameters(final Map<Symbol, String> value) =>
      _pathParametersStorage[token] = value;
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
      _ => throw UnimplementedError(),
    };
  }
}
