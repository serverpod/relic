import 'dart:async';

import 'package:relic/relic.dart';
import 'package:relic/src/adapter/context.dart';
import 'package:test/test.dart';

void main() {
  group('Router.inject with HandlerObject', () {
    test('Given a HandlerObject, '
        'when injected into router, '
        'then it is registered with default injectIn behavior', () async {
      final router = Router<Handler>();
      router.inject(const _EchoHandlerObject());

      final request = Request(
        Method.post,
        Uri.parse('http://localhost/'),
        body: Body.fromString('Hello from the other side'),
      );
      final ctx = request.toContext(Object());
      final result = await router.asHandler(ctx) as ResponseContext;

      expect(result.response.statusCode, 200);
      expect(await result.response.readAsString(), 'Hello from the other side');
    });

    test('Given a HandlerObject with custom injectIn, '
        'when injected into router, '
        'then custom path and method are used', () async {
      final router = Router<Handler>();
      router.inject(const _EchoHandlerObject(mountAt: '/custom/path'));

      final request = Request(
        Method.post,
        Uri.parse('http://localhost/custom/path'),
        body: Body.fromString('custom handler'),
      );
      final ctx = request.toContext(Object());
      final result = await router.asHandler(ctx) as ResponseContext;

      expect(result.response.statusCode, 200);
      expect(await result.response.readAsString(), 'custom handler');
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
        router.get('/test', (final ctx) => ctx.respond(Response.ok()));

        final request = Request(Method.get, Uri.parse('http://localhost/test'));
        final ctx = request.toContext(Object());
        final result = await router.asHandler(ctx) as ResponseContext;

        expect(result.response.statusCode, 200);
        expect(result.response.headers['X-Middleware'], ['applied']);
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
      router.get('/api/users', (final ctx) => ctx.respond(Response.ok()));
      router.get('/other', (final ctx) => ctx.respond(Response.ok()));

      // Should apply to /api/* paths
      final apiRequest = Request(
        Method.get,
        Uri.parse('http://localhost/api/users'),
      );
      final apiCtx = apiRequest.toContext(Object());
      final apiResult = await router.asHandler(apiCtx) as ResponseContext;

      expect(apiResult.response.statusCode, 200);
      expect(apiResult.response.headers['X-Custom-Middleware'], ['yes']);

      // Should NOT apply to other paths
      final otherRequest = Request(
        Method.get,
        Uri.parse('http://localhost/other'),
      );
      final otherCtx = otherRequest.toContext(Object());
      final otherResult = await router.asHandler(otherCtx) as ResponseContext;

      expect(otherResult.response.statusCode, 200);
      expect(otherResult.response.headers['X-Custom-Middleware'], isNull);
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
      router.get('/test', (final ctx) => ctx.respond(Response.ok()));

      final request = Request(Method.get, Uri.parse('http://localhost/test'));
      final ctx = request.toContext(Object());
      final result = await router.asHandler(ctx) as ResponseContext;

      expect(result.response.statusCode, 200);
      expect(result.response.headers['X-Middleware'], ['applied']);
      expect(result.response.headers['X-Second'], ['also-applied']);
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
  FutureOr<HandledContext> call(final NewContext ctx) {
    final data = ctx.request.body.read();
    return ctx.respond(Response.ok(body: Body.fromDataStream(data)));
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
    return (final ctx) async {
      final result = await next(ctx);
      if (result is! ResponseContext) return result;
      return result.respond(
        result.response.copyWith(
          headers: result.response.headers.transform(update),
        ),
      );
    };
  }
}
