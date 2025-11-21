import 'package:relic/relic.dart';
import 'package:relic/src/context/result.dart';
import 'package:test/test.dart';

void main() {
  group('MiddlewareObject', () {
    test('Given a MiddlewareObject, '
        'when used as middleware via call, '
        'then it wraps the handler correctly', () async {
      final middlewareObject = _TestMiddlewareObject();
      final router = Router<Handler>();
      router.use('/', middlewareObject.call);
      router.get('/test', (final req) => Response.ok());

      final request = RequestInternal.create(
        Method.get,
        Uri.parse('http://localhost/test'),
        Object(),
      );
      final req = request;
      final result = await router.asHandler(req) as Response;

      expect(result.statusCode, 200);
      expect(result.headers['X-Middleware'], ['applied']);
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
      router.get('/test', (final req) => Response.ok());

      final request = RequestInternal.create(
        Method.get,
        Uri.parse('http://localhost/test'),
        Object(),
      );
      final req = request;
      final result = await router.asHandler(req) as Response;

      expect(result.statusCode, 200);
      expect(result.headers['X-Middleware'], ['applied']);
    });

    test('Given a MiddlewareObject that modifies requests, '
        'when it wraps a handler, '
        'then the handler receives the modified context', () async {
      final middlewareObject = _RequestModifyingMiddleware();
      final router = Router<Handler>();
      router.use('/', middlewareObject.call);

      String? capturedHeader;
      router.get('/test', (final req) {
        capturedHeader = req.headers['X-Added']?.first;
        return Response.ok();
      });

      final request = RequestInternal.create(
        Method.get,
        Uri.parse('http://localhost/test'),
        Object(),
      );
      final req = request;
      await router.asHandler(req);

      expect(capturedHeader, 'by-middleware');
    });

    test('Given a MiddlewareObject that can short-circuit, '
        'when it returns early, '
        'then the next handler is not called', () async {
      final middlewareObject = _ShortCircuitMiddleware();
      final router = Router<Handler>();
      router.use('/', middlewareObject.call);

      var nextCalled = false;
      router.get('/test', (final req) {
        nextCalled = true;
        return Response.ok();
      });

      final request = RequestInternal.create(
        Method.get,
        Uri.parse('http://localhost/test'),
        Object(),
      );
      final req = request;
      final result = await router.asHandler(req) as Response;

      expect(nextCalled, isFalse);
      expect(result.statusCode, 403);
      expect(await result.readAsString(), 'Forbidden');
    });
  });
}

// Test implementations
class _TestMiddlewareObject extends MiddlewareObject {
  @override
  Handler call(final Handler next) {
    return (final req) async {
      final result = await next(req);
      if (result is! Response) return result;
      return result.copyWith(
        headers: result.headers.transform(
          (final h) => h['X-Middleware'] = ['applied'],
        ),
      );
    };
  }
}

class _RequestModifyingMiddleware extends MiddlewareObject {
  @override
  Handler call(final Handler next) {
    return (final req) async {
      // Modify the request by adding a header
      final modifiedRequest = req.copyWith(
        headers: req.headers.transform(
          (final h) => h['X-Added'] = ['by-middleware'],
        ),
      );
      return next(modifiedRequest);
    };
  }
}

class _ShortCircuitMiddleware extends MiddlewareObject {
  @override
  Handler call(final Handler next) {
    return (final req) async {
      // Short-circuit without calling next
      return Response.forbidden(body: Body.fromString('Forbidden'));
    };
  }
}
