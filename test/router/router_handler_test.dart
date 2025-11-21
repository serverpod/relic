import 'package:relic/relic.dart';
import 'package:relic/src/context/result.dart';
import 'package:test/test.dart';

Request _request(
  final String path, {
  final String host = 'localhost',
  final Method method = Method.get,
}) => RequestInternal.create(method, Uri.http(host, path), Object());

void main() {
  test('Given a router with a GET route, '
      'when calling router with matching GET request, '
      'then the handler is invoked and returns response', () async {
    final router = RelicRouter();
    var handlerCalled = false;
    router.get('/test', (final req) {
      handlerCalled = true;
      return Response.ok(body: Body.fromString('success'));
    });

    final request = _request('/test');
    final req = request;
    final result = await router.asHandler(req) as Response;

    expect(handlerCalled, isTrue);
    expect(result.statusCode, 200);
  });

  test('Given a router with a parameterized route, '
      'when calling router with matching request, '
      'then path parameters are accessible via context', () async {
    final router = RelicRouter();
    String? capturedName;
    String? capturedAge;
    router.get('/user/:name/age/:age', (final req) {
      capturedName = req.pathParameters[#name];
      capturedAge = req.pathParameters[#age];
      return Response.ok();
    });

    final request = _request('/user/alice/age/30');
    final req = request;
    await router.asHandler(req);

    expect(capturedName, 'alice');
    expect(capturedAge, '30');
  });

  test('Given a router with a GET route, '
      'when calling router with POST to same path, '
      'then returns 405 with Allow header', () async {
    final router = RelicRouter();
    router.get('/test', (final req) => Response.ok());

    final request = _request('/test', method: Method.post);
    final req = request;
    final result = await router.asHandler(req) as Response;

    expect(result.statusCode, 405);
    expect(result.headers.allow, contains(Method.get));
  });

  test('Given a router with multiple methods on same path, '
      'when calling router with unregistered method, '
      'then returns 405 with all allowed methods in Allow header', () async {
    final router = RelicRouter();
    router.get('/test', (final req) => Response.ok());
    router.post('/test', (final req) => Response.ok());

    final request = _request('/test', method: Method.put);
    final req = request;
    final result = await router.asHandler(req) as Response;

    expect(result.statusCode, 405);
    expect(result.headers.allow, containsAll([Method.get, Method.post]));
  });

  test('Given a router with routes, '
      'when calling router with unmatched path, '
      'then returns 404', () async {
    final router = RelicRouter();
    router.get('/test', (final req) => Response.ok());

    final request = _request('/nonexistent');
    final req = request;
    final result = await router.asHandler(req) as Response;

    expect(result.statusCode, 404);
  });

  test('Given a router with fallback handler, '
      'when path misses in router, '
      'then fallback handler is called', () async {
    final router = RelicRouter();
    router.get('/api/users', (final req) => Response.ok());

    var fallbackCalled = false;
    router.fallback = (final req) {
      fallbackCalled = true;
      return Response.ok(body: Body.fromString('fallback'));
    };

    final handler = router.asHandler;

    final request = _request('/other');
    final req = request;
    final result = await handler(req) as Response;

    expect(fallbackCalled, isTrue);
    expect(result.statusCode, 200);
  });

  test('Given a router with tail segment route, '
      'when calling router with path matching tail, '
      'then remaining path is accessible via context', () async {
    final router = RelicRouter();
    String? capturedRemaining;
    router.get('/static/**', (final req) {
      capturedRemaining = req.remainingPath.toString();
      return Response.ok();
    });

    final request = _request('/static/css/main.css');
    final req = request;
    await router.asHandler(req);

    expect(capturedRemaining, '/css/main.css');
  });

  test('Given a router with nested routes, '
      'when calling router with matching request, '
      'then matched path is accessible via context', () async {
    final router = RelicRouter();
    String? capturedMatched;
    router.get('/api/v1/users', (final req) {
      capturedMatched = req.matchedPath.toString();
      return Response.ok();
    });

    final request = _request('/api/v1/users');
    final req = request;
    await router.asHandler(req);

    expect(capturedMatched, '/api/v1/users');
  });

  test('Given a router with wildcard segment, '
      'when calling router with matching path, '
      'then handler is invoked', () async {
    final router = RelicRouter();
    var handlerCalled = false;
    router.get('/files/*/download', (final req) {
      handlerCalled = true;
      return Response.ok();
    });

    final request = _request('/files/doc123/download');
    final req = request;
    await router.asHandler(req);

    expect(handlerCalled, isTrue);
  });

  test('Given an empty router, '
      'when calling router with any request, '
      'then returns 404', () async {
    final router = RelicRouter();

    final request = _request('/anything');
    final req = request;
    final result = await router.asHandler(req) as Response;

    expect(result.statusCode, 404);
  });

  test('Given a router with use applied, '
      'when calling router with matching request, '
      'then middleware transformation is applied', () async {
    final router = RelicRouter();
    router.get('/test', (final req) => Response.ok());
    router.use('/', (final handler) {
      return (final req) async {
        final result = await handler(req) as Response;
        return result.copyWith(
          headers: Headers.build((final h) => h['X-Custom'] = ['applied']),
        );
      };
    });

    final request = _request('/test');
    final req = request;
    final result = await router.asHandler(req) as Response;

    expect(result.headers['X-Custom'], ['applied']);
  });

  test('Given a router with fallback set, '
      'when calling router with unmatched path, '
      'then fallback handler is called', () async {
    final router = RelicRouter();
    router.get('/users', (final req) => Response.ok());

    var fallbackCalled = false;
    router.fallback = (final req) {
      fallbackCalled = true;
      return Response.ok(body: Body.fromString('fallback response'));
    };

    final request = _request('/nonexistent');
    final req = request;
    final result = await router.asHandler(req) as Response;

    expect(fallbackCalled, isTrue);
    expect(result.statusCode, 200);
    expect(await result.readAsString(), 'fallback response');
  });

  test('Given a router without fallback set, '
      'when calling router with unmatched path, '
      'then returns 404', () async {
    final router = RelicRouter();
    router.get('/users', (final req) => Response.ok());
    // No fallback set

    final request = _request('/nonexistent');
    final req = request;
    final result = await router.asHandler(req) as Response;

    expect(result.statusCode, 404);
  });

  test('Given a router with fallback set, '
      'when calling router with method miss, '
      'then returns 405 (not fallback)', () async {
    final router = RelicRouter();
    router.get('/users', (final req) => Response.ok());

    var fallbackCalled = false;
    router.fallback = (final req) {
      fallbackCalled = true;
      return Response.ok();
    };

    final request = _request('/users', method: Method.post);
    final req = request;
    final result = await router.asHandler(req) as Response;

    expect(fallbackCalled, isFalse);
    expect(result.statusCode, 405);
    expect(result.headers.allow, contains(Method.get));
  });

  test('Given a router with fallback, '
      'when fallback is overwritten, '
      'then new fallback is used', () async {
    final router = RelicRouter();
    router.get('/users', (final req) => Response.ok());

    router.fallback =
        (final req) => Response.ok(body: Body.fromString('first fallback'));

    router.fallback =
        (final req) => Response.ok(body: Body.fromString('second fallback'));

    final request = _request('/nonexistent');
    final req = request;
    final result = await router.asHandler(req) as Response;

    expect(await result.readAsString(), 'second fallback');
  });

  test('Given a router with fallback set to null, '
      'when calling router with unmatched path, '
      'then returns 404', () async {
    final router = RelicRouter();
    router.get('/users', (final req) => Response.ok());

    router.fallback =
        (final req) => Response.ok(body: Body.fromString('fallback'));
    router.fallback = null; // Clear fallback

    final request = _request('/nonexistent');
    final req = request;
    final result = await router.asHandler(req) as Response;

    expect(result.statusCode, 404);
  });
}
