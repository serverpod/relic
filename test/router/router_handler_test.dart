import 'package:mockito/mockito.dart';
import 'package:relic/relic.dart';
import 'package:relic/src/adapter/context.dart';
import 'package:test/test.dart';

// Simple fake implementations for testing
class _FakeRequest extends Fake implements Request {
  @override
  final Uri url;
  @override
  final Method method;

  _FakeRequest(
    final String path, {
    final String host = 'localhost',
    this.method = Method.get,
  }) : url = Uri.parse('http://$host$path');
}

void main() {
  test('Given a router with a GET route, '
      'when calling router with matching GET request, '
      'then the handler is invoked and returns response', () async {
    final router = RelicRouter();
    var handlerCalled = false;
    router.get('/test', (final ctx) {
      handlerCalled = true;
      return ctx.respond(Response.ok(body: Body.fromString('success')));
    });

    final request = _FakeRequest('/test');
    final ctx = request.toContext(Object());
    final result = await router.asHandler(ctx) as ResponseContext;

    expect(handlerCalled, isTrue);
    expect(result.response.statusCode, 200);
  });

  test('Given a router with a parameterized route, '
      'when calling router with matching request, '
      'then path parameters are accessible via context', () async {
    final router = RelicRouter();
    String? capturedName;
    String? capturedAge;
    router.get('/user/:name/age/:age', (final ctx) {
      capturedName = ctx.pathParameters[#name];
      capturedAge = ctx.pathParameters[#age];
      return ctx.respond(Response.ok());
    });

    final request = _FakeRequest('/user/alice/age/30');
    final ctx = request.toContext(Object());
    await router.asHandler(ctx);

    expect(capturedName, 'alice');
    expect(capturedAge, '30');
  });

  test('Given a router with a GET route, '
      'when calling router with POST to same path, '
      'then returns 405 with Allow header', () async {
    final router = RelicRouter();
    router.get('/test', (final ctx) => ctx.respond(Response.ok()));

    final request = _FakeRequest('/test', method: Method.post);
    final ctx = request.toContext(Object());
    final result = await router.asHandler(ctx) as ResponseContext;

    expect(result.response.statusCode, 405);
    expect(result.response.headers.allow, contains(Method.get));
  });

  test('Given a router with multiple methods on same path, '
      'when calling router with unregistered method, '
      'then returns 405 with all allowed methods in Allow header', () async {
    final router = RelicRouter();
    router.get('/test', (final ctx) => ctx.respond(Response.ok()));
    router.post('/test', (final ctx) => ctx.respond(Response.ok()));

    final request = _FakeRequest('/test', method: Method.put);
    final ctx = request.toContext(Object());
    final result = await router.asHandler(ctx) as ResponseContext;

    expect(result.response.statusCode, 405);
    expect(
      result.response.headers.allow,
      containsAll([Method.get, Method.post]),
    );
  });

  test('Given a router with routes, '
      'when calling router with unmatched path, '
      'then returns 404', () async {
    final router = RelicRouter();
    router.get('/test', (final ctx) => ctx.respond(Response.ok()));

    final request = _FakeRequest('/nonexistent');
    final ctx = request.toContext(Object());
    final result = await router.asHandler(ctx) as ResponseContext;

    expect(result.response.statusCode, 404);
  });

  test('Given a router with fallback handler, '
      'when path misses in router, '
      'then fallback handler is called', () async {
    final router = RelicRouter();
    router.get('/api/users', (final ctx) => ctx.respond(Response.ok()));

    var fallbackCalled = false;
    router.fallback = (final ctx) {
      fallbackCalled = true;
      return ctx.respond(Response.ok(body: Body.fromString('fallback')));
    };

    final handler = router.asHandler;

    final request = _FakeRequest('/other');
    final ctx = request.toContext(Object());
    final result = await handler(ctx) as ResponseContext;

    expect(fallbackCalled, isTrue);
    expect(result.response.statusCode, 200);
  });

  test('Given a router with tail segment route, '
      'when calling router with path matching tail, '
      'then remaining path is accessible via context', () async {
    final router = RelicRouter();
    String? capturedRemaining;
    router.get('/static/**', (final ctx) {
      capturedRemaining = ctx.remainingPath.toString();
      return ctx.respond(Response.ok());
    });

    final request = _FakeRequest('/static/css/main.css');
    final ctx = request.toContext(Object());
    await router.asHandler(ctx);

    expect(capturedRemaining, '/css/main.css');
  });

  test('Given a router with nested routes, '
      'when calling router with matching request, '
      'then matched path is accessible via context', () async {
    final router = RelicRouter();
    String? capturedMatched;
    router.get('/api/v1/users', (final ctx) {
      capturedMatched = ctx.matchedPath.toString();
      return ctx.respond(Response.ok());
    });

    final request = _FakeRequest('/api/v1/users');
    final ctx = request.toContext(Object());
    await router.asHandler(ctx);

    expect(capturedMatched, '/api/v1/users');
  });

  test('Given a router with wildcard segment, '
      'when calling router with matching path, '
      'then handler is invoked', () async {
    final router = RelicRouter();
    var handlerCalled = false;
    router.get('/files/*/download', (final ctx) {
      handlerCalled = true;
      return ctx.respond(Response.ok());
    });

    final request = _FakeRequest('/files/doc123/download');
    final ctx = request.toContext(Object());
    await router.asHandler(ctx);

    expect(handlerCalled, isTrue);
  });

  test('Given an empty router, '
      'when calling router with any request, '
      'then returns 404', () async {
    final router = RelicRouter();

    final request = _FakeRequest('/anything');
    final ctx = request.toContext(Object());
    final result = await router.asHandler(ctx) as ResponseContext;

    expect(result.response.statusCode, 404);
  });

  test('Given a router with use applied, '
      'when calling router with matching request, '
      'then middleware transformation is applied', () async {
    final router = RelicRouter();
    router.get('/test', (final ctx) => ctx.respond(Response.ok()));
    router.use('/', (final handler) {
      return (final ctx) async {
        final result = await handler(ctx) as ResponseContext;
        return result.respond(
          result.response.copyWith(
            headers: Headers.build((final h) => h['X-Custom'] = ['applied']),
          ),
        );
      };
    });

    final request = _FakeRequest('/test');
    final ctx = request.toContext(Object());
    final result = await router.asHandler(ctx) as ResponseContext;

    expect(result.response.headers['X-Custom'], ['applied']);
  });

  test('Given a router with fallback set, '
      'when calling router with unmatched path, '
      'then fallback handler is called', () async {
    final router = RelicRouter();
    router.get('/users', (final ctx) => ctx.respond(Response.ok()));

    var fallbackCalled = false;
    router.fallback = (final ctx) {
      fallbackCalled = true;
      return ctx.respond(
        Response.ok(body: Body.fromString('fallback response')),
      );
    };

    final request = _FakeRequest('/nonexistent');
    final ctx = request.toContext(Object());
    final result = await router.asHandler(ctx) as ResponseContext;

    expect(fallbackCalled, isTrue);
    expect(result.response.statusCode, 200);
    expect(await result.response.readAsString(), 'fallback response');
  });

  test('Given a router without fallback set, '
      'when calling router with unmatched path, '
      'then returns 404', () async {
    final router = RelicRouter();
    router.get('/users', (final ctx) => ctx.respond(Response.ok()));
    // No fallback set

    final request = _FakeRequest('/nonexistent');
    final ctx = request.toContext(Object());
    final result = await router.asHandler(ctx) as ResponseContext;

    expect(result.response.statusCode, 404);
  });

  test('Given a router with fallback set, '
      'when calling router with method miss, '
      'then returns 405 (not fallback)', () async {
    final router = RelicRouter();
    router.get('/users', (final ctx) => ctx.respond(Response.ok()));

    var fallbackCalled = false;
    router.fallback = (final ctx) {
      fallbackCalled = true;
      return ctx.respond(Response.ok());
    };

    final request = _FakeRequest('/users', method: Method.post);
    final ctx = request.toContext(Object());
    final result = await router.asHandler(ctx) as ResponseContext;

    expect(fallbackCalled, isFalse);
    expect(result.response.statusCode, 405);
    expect(result.response.headers.allow, contains(Method.get));
  });

  test('Given a router with fallback, '
      'when fallback is overwritten, '
      'then new fallback is used', () async {
    final router = RelicRouter();
    router.get('/users', (final ctx) => ctx.respond(Response.ok()));

    router.fallback =
        (final ctx) =>
            ctx.respond(Response.ok(body: Body.fromString('first fallback')));

    router.fallback =
        (final ctx) =>
            ctx.respond(Response.ok(body: Body.fromString('second fallback')));

    final request = _FakeRequest('/nonexistent');
    final ctx = request.toContext(Object());
    final result = await router.asHandler(ctx) as ResponseContext;

    expect(await result.response.readAsString(), 'second fallback');
  });

  test('Given a router with fallback set to null, '
      'when calling router with unmatched path, '
      'then returns 404', () async {
    final router = RelicRouter();
    router.get('/users', (final ctx) => ctx.respond(Response.ok()));

    router.fallback =
        (final ctx) =>
            ctx.respond(Response.ok(body: Body.fromString('fallback')));
    router.fallback = null; // Clear fallback

    final request = _FakeRequest('/nonexistent');
    final ctx = request.toContext(Object());
    final result = await router.asHandler(ctx) as ResponseContext;

    expect(result.response.statusCode, 404);
  });
}
