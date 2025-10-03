import 'package:relic/relic.dart';
import 'package:relic/src/router/lookup_result.dart';
import 'package:relic/src/router/method.dart';
import 'package:relic/src/router/router.dart';
import 'package:test/test.dart';

import '../headers/headers_test_utils.dart';
import '../util/test_util.dart';

import 'package:http/http.dart' as http;

void main() {
  test(
      'Given a route at root, '
      'when use is applied to root, '
      'then the value is transformed', () {
    final router = Router<int>();
    router.get('/', 1);
    router.use('/', (final i) => i * 2);
    final result = router.lookup(Method.get, '/') as RouterMatch<int>;
    expect(result.value, 2, reason: 'Should double');
  });

  test(
      'Given a route at path, '
      'when use is applied twice to path, '
      'then the mappings compose', () {
    final router = Router<int>();
    router.get('/a', 1);
    router.use('/a', (final i) => i * 2);
    router.use('/a', (final i) => i + 3);
    final result = router.lookup(Method.get, '/a') as RouterMatch<int>;
    expect(result.value, 8, reason: 'Should add 3 and then double');
  });

  test(
      'Given an empty router, '
      'when use is applied before add, '
      'then the value is transformed', () {
    final router = Router<int>();
    router.use('/', (final i) => i * 2);
    router.get('/', 1);
    final result = router.lookup(Method.get, '/') as RouterMatch<int>;
    expect(result.value, 2, reason: 'Should double');
  });

  test(
      'Given routes at multiple paths, '
      'when use is applied to root, '
      'then all descendant routes are transformed', () {
    final router = Router<int>();
    router.get('/', 1);
    router.get('/a', 10);
    router.get('/b', 100);
    router.use('/', (final i) => i * 2);
    expect((router.lookup(Method.get, '/') as RouterMatch<int>).value, 2,
        reason: 'Should double');
    expect((router.lookup(Method.get, '/a') as RouterMatch<int>).value, 20,
        reason: 'Should double');
    expect((router.lookup(Method.get, '/b') as RouterMatch<int>).value, 200,
        reason: 'Should double');
  });

  test(
      'Given routes at multiple paths, '
      'when use is applied to a specific path, '
      'then only descendants of that path are transformed', () {
    final router = Router<int>();
    router.get('/', 1);
    router.get('/a', 10);
    router.get('/b', 100);
    router.use('/a', (final i) => i * 2);
    expect((router.lookup(Method.get, '/') as RouterMatch<int>).value, 1,
        reason: 'Should not change');
    expect((router.lookup(Method.get, '/a') as RouterMatch<int>).value, 20,
        reason: 'Should double');
    expect((router.lookup(Method.get, '/b') as RouterMatch<int>).value, 100,
        reason: 'Should not change');
  });

  test(
      'Given routes with different HTTP methods, '
      'when use is applied, '
      'then all methods at that path are transformed', () {
    final router = Router<int>();
    router.get('/api', 1);
    router.post('/api', 2);
    router.put('/api', 3);
    router.use('/api', (final i) => i * 10);
    expect((router.lookup(Method.get, '/api') as RouterMatch<int>).value, 10);
    expect((router.lookup(Method.post, '/api') as RouterMatch<int>).value, 20);
    expect((router.lookup(Method.put, '/api') as RouterMatch<int>).value, 30);
  });

  test(
      'Given two routers where one is attached to the other, '
      'when use is applied to the prefix on the parent, '
      'then only attached router routes are transformed', () {
    final routerA = Router<int>();
    final routerB = Router<int>();
    routerA.get('/a', 10);
    routerB.get('/b', 100);
    routerA.attach('/prefix', routerB);
    routerA.use('/prefix', (final i) => i * 2);
    expect((routerA.lookup(Method.get, '/a') as RouterMatch<int>).value, 10,
        reason: 'Should not change');
    expect(
      (routerA.lookup(Method.get, '/prefix/b') as RouterMatch<int>).value,
      200,
      reason: 'Should double',
    );
  });

  test(
      'Given two routers with use applied, '
      'when attaching one to the other such that use collide, '
      'then map functions are composed', () {
    final routerA = Router<int>();
    final routerB = Router<int>();
    routerA.use('/prefix', (final i) => i * 2);
    routerB.get('/suffix', 1);
    routerB.use('/', (final i) => i + 3);
    routerA.attach('/prefix', routerB);
    expect(
      (routerA.lookup(Method.get, '/prefix/suffix') as RouterMatch<int>).value,
      8,
      reason: 'Should add 3 and then double',
    );
  });

  test(
      'Given hierarchical use mappings, '
      'when looking up a route, '
      'then transformations are applied from leaf to root', () {
    final router = Router<int>();
    router.get('/a/b', 1);
    router.use('/a', (final i) => i * 2);
    router.use('/a/b', (final i) => i + 3);
    expect(
      (router.lookup(Method.get, '/a/b') as RouterMatch<int>).value,
      8,
      reason: 'Should add 3 and then double',
    );
  });

  test(
      'Given a router of middleware functions with hierarchical use, '
      'when looking up and applying the route function, '
      'then the call order is root to leaf', () {
    final router = Router<String Function(String)>();
    router.use('/a', (final next) => (final s) => '<a>${next(s)}</a>');
    router.use('/a/b', (final next) => (final s) => '<b>${next(s)}</b>');
    router.use('/a/b/c', (final next) => (final s) => '<c>${next(s)}</c>');
    router.get('/a/b/c/d', (final s) => s);
    final result = router.lookup(Method.get, '/a/b/c/d')
        as RouterMatch<String Function(String)>;
    expect(
      result.value('request'),
      '<a><b><c>request</c></b></a>',
    );
  });

  test(
      'Given authentication middleware, '
      'when a handler is invoked, '
      'then it can retrieve the user', () async {
    final router = Router<Handler>();
    router
      ..use('/', AuthMiddleware().call)
      ..get(
          '/api/user/info',
          (final ctx) =>
              ctx.respond(Response.ok(body: Body.fromString('${ctx.user}'))));

    final relic = await testServe(const Pipeline()
        .addMiddleware(routeWith(router))
        .addHandler(respondWith((final _) => Response.notFound())));

    final response =
        await http.get(relic.url.replace(path: '/api/user/info'), headers: {
      'Authorization': 'Bearer XYZ',
    });

    expect(response.statusCode, equals(200));
    expect(response.body, '42');
  });
}

typedef User = int;
final _auth = ContextProperty<User>('auth');

extension on RequestContext {
  User get user => _auth[this];
}

class AuthMiddleware {
  bool _validate(final String token) => true; // just an example
  User _extractUser(final String token) => 42;

  Handler call(final Handler next) {
    return (final ctx) {
      final bearer =
          ctx.request.headers.authorization as BearerAuthorizationHeader?;
      if (bearer == null || !_validate(bearer.token)) {
        return ctx.respond(Response.unauthorized());
      } else {
        _auth[ctx] = _extractUser(bearer.token);
        return next(ctx);
      }
    };
  }
}
