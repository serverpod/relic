import 'package:relic/relic.dart';
import 'package:test/test.dart';

void main() {
  group('Router.group', () {
    test(
        'Given a router with a group, '
        'when registering a path on the group, '
        'then it is correctly placed in the hierarchy', () {
      final router = Router<String>();
      final api = router.group('/api');
      api.get('/users', 'users');

      final result = router.lookup(Method.get, '/api/users');
      expect(result, isNotNull);
      expect(result!.value, 'users');

      final failedResult = router.lookup(Method.get, '/users');
      expect(failedResult, isNull);
    });

    test(
        'Given a router with nested groups, '
        'when registering a path on the child group, '
        'then it is correctly placed in the hierarchy', () {
      final router = Router<String>();
      final api = router.group('/api');
      final v1 = api.group('/v1');
      v1.get('/posts', 'posts');

      final result = router.lookup(Method.get, '/api/v1/posts');
      expect(result, isNotNull);
      expect(result!.value, 'posts');

      final failedResult1 = router.lookup(Method.get, '/v1/posts');
      expect(failedResult1, isNull);

      final failedResult2 = router.lookup(Method.get, '/posts');
      expect(failedResult2, isNull);
    });

    test(
        'Given a router with a group at a parameterized path, '
        'when looking up a route with parameters, '
        'then the parameter is correctly set on lookup', () {
      final router = Router<String>();
      final users = router.group('/users/:userId');
      users.get('/profile', 'profile');

      final result = router.lookup(Method.get, '/users/123/profile');
      expect(result, isNotNull);
      expect(result!.value, 'profile');
      expect(result.parameters, {#userId: '123'});
    });

    test(
        'Given a router with multiple groups at the same level, '
        'when looking up routes from different groups, '
        "then each group's routes are correctly isolated", () {
      final router = Router<String>();

      final admin = router.group('/admin');
      admin.get('/dashboard', 'dashboard');

      final public = router.group('/public');
      public.get('/about', 'about');

      final adminResult = router.lookup(Method.get, '/admin/dashboard');
      expect(adminResult, isNotNull);
      expect(adminResult!.value, 'dashboard');

      final publicResult = router.lookup(Method.get, '/public/about');
      expect(publicResult, isNotNull);
      expect(publicResult!.value, 'about');
    });

    test(
        'Given a group path with trailing slash, '
        'when looking up routes with and without trailing slashes, '
        'then the group path is correctly normalized', () {
      final router = Router<String>();
      // Group path with trailing slash
      final api = router.group('/api/');
      api.get('/users', 'users');

      // Lookup path without trailing slash
      var result = router.lookup(Method.get, '/api/users');
      expect(result, isNotNull);
      expect(result!.value, 'users');

      // Lookup path with trailing slash
      result = router.lookup(Method.get, '/api/users/');
      expect(result, isNotNull);
      expect(result!.value, 'users');
    });

    test(
        'Given routes registered with and without leading slashes, '
        'when looking up the routes, '
        'then route paths inside groups are correctly normalized', () {
      final router = Router<String>();
      final api = router.group('/api');
      // Route with leading slash
      api.get('/users', 'users');
      // Route without leading slash
      api.get('posts', 'posts');

      final usersResult = router.lookup(Method.get, '/api/users');
      expect(usersResult, isNotNull);
      expect(usersResult!.value, 'users');

      final postsResult = router.lookup(Method.get, '/api/posts');
      expect(postsResult, isNotNull);
      expect(postsResult!.value, 'posts');
    });

    test(
        'Given nested groups with parameters, '
        'when looking up a deeply nested route, '
        'then all parameters are correctly extracted', () {
      final router = Router<String>();
      final group1 = router.group('/tenant/:tenantId');
      final group2 = group1.group('/users/:userId');
      group2.get('/data', 'some-data');

      final result = router.lookup(Method.get, '/tenant/abc/users/123/data');
      expect(result, isNotNull);
      expect(result!.value, 'some-data');
      expect(result.parameters, {#tenantId: 'abc', #userId: '123'});
    });

    test(
        'Given a router with conflicting group patterns, '
        'when attempting to add incompatible groups, '
        'then an ArgumentError is thrown', () {
      final router = Router<String>();
      router.group(':p');
      expect(() => router.group('*'), throwsArgumentError);
    });

    test(
        'Given two group instances with the same path, '
        'when comparing them and accessing routes, '
        'then they are not equal but share the same underlying routes', () {
      final router = Router<int>();
      final first = router.group('a')..get('b', 1);
      final second = router.group('a');
      final result = second.lookup(Method.get, 'b');
      expect(first, isNot(second));
      expect(result, isNotNull);
      expect(result!.value, 1);
    });

    test(
        'Given a router with an empty group, '
        'when looking up the group path directly, '
        'then no route is found', () {
      final router = Router<int>()..group('a');
      final result = router.lookup(Method.get, 'a');
      router.isEmpty;
      expect(result, isNull);
    });
  });
}
