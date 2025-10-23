import 'package:relic/relic.dart';
import 'package:relic/src/adapter/context.dart';
import 'package:test/test.dart';

void main() {
  group('MiddlewareObject', () {
    test('Given a MiddlewareObject, '
        'when used as middleware via call, '
        'then it wraps the handler correctly', () async {
      final middlewareObject = _TestMiddlewareObject();
      final router = Router<Handler>();
      router.use('/', middlewareObject.call);
      router.get('/test', (final ctx) => ctx.respond(Response.ok()));

      final request = Request(Method.get, Uri.parse('http://localhost/test'));
      final ctx = request.toContext(Object());
      final result = await router.asHandler(ctx) as ResponseContext;

      expect(result.response.statusCode, 200);
      expect(result.response.headers['X-Middleware'], ['applied']);
    });

    test('Given a MiddlewareObject, '
        'when asMiddleware getter is used, '
        'then it returns a valid Middleware function', () async {
      final middlewareObject = _TestMiddlewareObject();
      final middleware = middlewareObject.asMiddleware;

      // Verify it's callable as a Middleware
      expect(middleware, isA<Middleware>());

      final router = Router<Handler>();
      router.use('/', middleware);
      router.get('/test', (final ctx) => ctx.respond(Response.ok()));

      final request = Request(Method.get, Uri.parse('http://localhost/test'));
      final ctx = request.toContext(Object());
      final result = await router.asHandler(ctx) as ResponseContext;

      expect(result.response.statusCode, 200);
      expect(result.response.headers['X-Middleware'], ['applied']);
    });

    test('Given a MiddlewareObject that modifies requests, '
        'when it wraps a handler, '
        'then the handler receives the modified context', () async {
      final middlewareObject = _RequestModifyingMiddleware();
      final router = Router<Handler>();
      router.use('/', middlewareObject.call);

      String? capturedHeader;
      router.get('/test', (final ctx) {
        capturedHeader = ctx.request.headers['X-Added']?.first;
        return ctx.respond(Response.ok());
      });

      final request = Request(Method.get, Uri.parse('http://localhost/test'));
      final ctx = request.toContext(Object());
      await router.asHandler(ctx);

      expect(capturedHeader, 'by-middleware');
    });

    test('Given a MiddlewareObject that can short-circuit, '
        'when it returns early, '
        'then the inner handler is not called', () async {
      final middlewareObject = _ShortCircuitMiddleware();
      final router = Router<Handler>();
      router.use('/', middlewareObject.call);

      var innerHandlerCalled = false;
      router.get('/test', (final ctx) {
        innerHandlerCalled = true;
        return ctx.respond(Response.ok());
      });

      final request = Request(Method.get, Uri.parse('http://localhost/test'));
      final ctx = request.toContext(Object());
      final result = await router.asHandler(ctx) as ResponseContext;

      expect(innerHandlerCalled, isFalse);
      expect(result.response.statusCode, 403);
      expect(await result.response.readAsString(), 'Forbidden');
    });
  });
}

// Test implementations
class _TestMiddlewareObject extends MiddlewareObject {
  @override
  Handler call(final Handler next) {
    return (final ctx) async {
      final result = await next(ctx);
      if (result is! ResponseContext) return result;
      return result.respond(
        result.response.copyWith(
          headers: result.response.headers.transform(
            (final h) => h['X-Middleware'] = ['applied'],
          ),
        ),
      );
    };
  }
}

class _RequestModifyingMiddleware extends MiddlewareObject {
  @override
  Handler call(final Handler next) {
    return (final ctx) async {
      // Modify the request by adding a header
      final modifiedRequest = ctx.request.copyWith(
        headers: ctx.request.headers.transform(
          (final h) => h['X-Added'] = ['by-middleware'],
        ),
      );
      final modifiedCtx = ctx.withRequest(modifiedRequest);
      return next(modifiedCtx);
    };
  }
}

class _ShortCircuitMiddleware extends MiddlewareObject {
  @override
  Handler call(final Handler next) {
    return (final ctx) async {
      // Short-circuit without calling next
      return ctx.respond(
        Response.forbidden(body: Body.fromString('Forbidden')),
      );
    };
  }
}
