import 'package:relic/src/router/lookup_result.dart';
import 'package:relic/src/router/method.dart';
import 'package:relic/src/router/router.dart';
import 'package:test/test.dart';

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
}
