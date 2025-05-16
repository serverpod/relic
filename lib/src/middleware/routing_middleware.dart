import '../adapter/context.dart';
import '../handler/handler.dart';
import '../method/request_method.dart';
import '../router/router.dart';
import 'middleware.dart';

Middleware routeWith(final Router<Handler> router) =>
    RoutingMiddleware(router).meddle;

final _pathParametersStorage = Expando<Map<Symbol, String>>();

class RoutingMiddleware {
  final Router<Handler> _router;

  RoutingMiddleware(this._router);

  Handler meddle(final Handler next) {
    return (final ctx) async {
      final req = ctx.request;
      final url = ctx.request.url; // TODO: Use requestUri
      final match = _router.lookup(req.method.convert(), url.path);
      if (match != null) {
        ctx._pathParameters = match.parameters;
        final handler = match.value;
        return await handler(ctx);
      } else {
        return await next(ctx);
      }
    };
  }
}

extension RequestContextEx on RequestContext {
  Map<Symbol, String> get pathParameters =>
      _pathParametersStorage[token] ??
      (throw StateError('Add RoutingMiddleware!'));

  set _pathParameters(final Map<Symbol, String> value) =>
      _pathParametersStorage[token] = value;
}

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
