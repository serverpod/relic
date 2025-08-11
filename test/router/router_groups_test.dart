import 'package:relic/relic.dart';
import 'package:test/test.dart';

void main() {
  group('Router.group', () {
    test(
        'Given a router with a group'
        'when registering a path on the group'
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
        'Given a router with nested groups'
        'when registering a path on the child group'
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
        'Given a router with a group at a parameterized path'
        'then the parameter is correctly set on lookup', () {
      final router = Router<String>();
      final users = router.group('/users/:userId');
      users.get('/profile', 'profile');

      final result = router.lookup(Method.get, '/users/123/profile');
      expect(result, isNotNull);
      expect(result!.value, 'profile');
      expect(result.parameters, {#userId: '123'});
    });

    test('Can handle multiple groups at the same level', () {
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

    test('Group path is correctly normalized', () {
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

    test('Route path inside group is correctly normalized', () {
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

    test('Nested groups with parameters', () {
      final router = Router<String>();
      final group1 = router.group('/tenant/:tenantId');
      final group2 = group1.group('/users/:userId');
      group2.get('/data', 'some-data');

      final result = router.lookup(Method.get, '/tenant/abc/users/123/data');
      expect(result, isNotNull);
      expect(result!.value, 'some-data');
      expect(result.parameters, {#tenantId: 'abc', #userId: '123'});
    });

    test('Impossible', () {
      final router = Router<String>();
      router.group(':p');
      expect(() => router.group('*'), throwsArgumentError);
    });

    test('Equals', () {
      final router = Router<int>();
      final first = router.group('a')..get('b', 1);
      final second = router.group('a');
      final result = second.lookup(Method.get, 'b');
      expect(first, isNot(second));
      expect(result, isNotNull);
      expect(result!.value, 1);
    });

    test('Weird', () {
      final router = Router<int>()..group('a');
      final result = router.lookup(Method.get, 'a');
      router.isEmpty;
      expect(result, isNull);
    });
  });
}
