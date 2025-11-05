import 'dart:async';

import 'package:relic/relic.dart';
import 'package:relic/src/context/context.dart';
import 'package:test/test.dart';

void main() {
  group('Router.inject with HandlerObject', () {
    test('Given a HandlerObject, '
        'when injected into router, '
        'then it is registered with default injectIn behavior', () async {
      final router = Router<Handler>();
      router.inject(const _EchoHandlerObject());

      final request = RequestInternal.create(
        Method.post,
        Uri.parse('http://localhost/'),
        Object(),
        body: Body.fromString('Hello from the other side'),
      );
      final req = request;
      final result = await router.asHandler(req) as Response;

      expect(result.statusCode, 200);
      expect(await result.readAsString(), 'Hello from the other side');
    });

    test('Given a HandlerObject with custom injectIn, '
        'when injected into router, '
        'then custom path and method are used', () async {
      final router = Router<Handler>();
      router.inject(const _EchoHandlerObject(mountAt: '/custom/path'));

      final request = RequestInternal.create(
        Method.post,
        Uri.parse('http://localhost/custom/path'),
        Object(),
        body: Body.fromString('custom handler'),
      );
      final req = request;
      final result = await router.asHandler(req) as Response;

      expect(result.statusCode, 200);
      expect(await result.readAsString(), 'custom handler');
    });
  });

  group('Router.injectAt', () {
    test('Given a HandlerObject, '
        'when using injectAt, '
        'then it is injected at the specified path', () async {
      final router = Router<Handler>();
      router.injectAt('/api', const _EchoHandlerObject(mountAt: '/echo'));

      final request = RequestInternal.create(
        Method.post,
        Uri.parse('http://localhost/api/echo'),
        Object(),
        body: Body.fromString('injected at path'),
      );
      final req = request;
      final result = await router.asHandler(req) as Response;

      expect(result.statusCode, 200);
      expect(await result.readAsString(), 'injected at path');
    });
  });

  group('Router.inject with MiddlewareObject', () {
    test(
      'Given a MiddlewareObject, '
      'when injected into router, '
      'then it is registered with default injectIn behavior at root path',
      () async {
        final router = Router<Handler>();
        router.inject(
          _HeaderSetMiddlewareObject(
            (final mh) => mh['X-Middleware'] = ['applied'],
          ),
        );
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
      },
    );

    test('Given a MiddlewareObject with custom injectIn, '
        'when injected into router, '
        'then custom path is used', () async {
      final router = Router<Handler>();
      router.inject(
        _HeaderSetMiddlewareObject(
          (final mh) => mh['X-Custom-Middleware'] = ['yes'],
          mountAt: '/api',
        ),
      );
      router.get('/api/users', (final req) => Response.ok());
      router.get('/other', (final req) => Response.ok());

      // Should apply to /api/* paths
      final apiRequest = RequestInternal.create(
        Method.get,
        Uri.parse('http://localhost/api/users'),
        Object(),
      );
      final apiCtx = apiRequest;
      final apiResult = await router.asHandler(apiCtx) as Response;

      expect(apiResult.statusCode, 200);
      expect(apiResult.headers['X-Custom-Middleware'], ['yes']);

      // Should NOT apply to other paths
      final otherRequest = RequestInternal.create(
        Method.get,
        Uri.parse('http://localhost/other'),
        Object(),
      );
      final otherCtx = otherRequest;
      final otherResult = await router.asHandler(otherCtx) as Response;

      expect(otherResult.statusCode, 200);
      expect(otherResult.headers['X-Custom-Middleware'], isNull);
    });

    test('Given multiple MiddlewareObjects, '
        'when injected into router, '
        'then they are all registered and compose correctly', () async {
      final router = Router<Handler>();
      router.inject(
        _HeaderSetMiddlewareObject(
          (final mh) => mh['X-Middleware'] = ['applied'],
        ),
      );
      router.inject(
        _HeaderSetMiddlewareObject(
          (final mh) => mh['X-Second'] = ['also-applied'],
        ),
      );
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
      expect(result.headers['X-Second'], ['also-applied']);
    });
  });
}

// Test implementations - HandlerObject
class _EchoHandlerObject extends HandlerObject {
  final String mountAt;

  const _EchoHandlerObject({this.mountAt = '/'});

  @override
  void injectIn(final Router<Handler> router) => router.post(mountAt, call);

  @override
  FutureOr<Result> call(final Request req) {
    final data = req.body.read();
    return Response.ok(body: Body.fromDataStream(data));
  }
}

// Test implementations - MiddlewareObject
class _HeaderSetMiddlewareObject extends MiddlewareObject {
  final void Function(MutableHeaders) update;
  final String mountAt;

  _HeaderSetMiddlewareObject(this.update, {this.mountAt = '/'});

  @override
  void injectIn(final Router<Handler> router) => router.use(mountAt, call);

  @override
  Handler call(final Handler next) {
    return (final req) async {
      final result = await next(req);
      if (result is! Response) return result;
      return result.copyWith(headers: result.headers.transform(update));
    };
  }
}
