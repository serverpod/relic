import 'package:relic/relic.dart';
import 'package:test/test.dart';

void main() {
  void expectLookupResult<T>(
    final LookupResult<T>? actual,
    final T expectedValue, [
    final Map<Symbol, String> expectedParams = const {},
  ]) {
    expect(actual, isNotNull);
    if (actual == null) throw AssertionError();
    expect(actual.value, equals(expectedValue));
    expect(actual.parameters, equals(expectedParams));
  }

  group('Router.group', () {
    group('Given a router with a group and registered path', () {
      late Router<String> router;

      setUp(() {
        router = Router<String>();
        final api = router.group('/api');
        api.get('/users', 'users');
      });

      test(
          'when looking up the grouped path, then it returns the correct value',
          () {
        final result = router.lookup(Method.get, '/api/users');
        expectLookupResult(result, 'users');
      });

      test('when looking up the non-grouped path, then it fails', () {
        final failedResult = router.lookup(Method.get, '/users');
        expect(failedResult, null);
      });
    });

    group('Given a router with nested groups and registered path', () {
      late Router<String> router;

      setUp(() {
        router = Router<String>();
        final api = router.group('/api');
        final v1 = api.group('/v1');
        v1.get('/posts', 'posts');
      });

      test(
          'when looking up the fully nested path, then it returns the correct value',
          () {
        final result = router.lookup(Method.get, '/api/v1/posts');
        expectLookupResult(result, 'posts');
      });

      test('when looking up partial path /v1/posts, then it fails', () {
        final failedResult = router.lookup(Method.get, '/v1/posts');
        expect(failedResult, null);
      });

      test('when looking up partial path /posts, then it fails', () {
        final failedResult = router.lookup(Method.get, '/posts');
        expect(failedResult, null);
      });
    });

    test(
        'Given a router with a parameterized group and registered path, '
        'when looking up a route with parameter values, '
        'then it returns the correct value with extracted parameters', () {
      final router = Router<String>();
      final users = router.group('/users/:userId');
      users.get('/profile', 'profile');

      final result = router.lookup(Method.get, '/users/123/profile');
      expect(result, isNotNull);
      expect(result!.value, 'profile');
      expect(result.parameters, {#userId: '123'});
    });

    group('Given a router with multiple sibling groups and registered paths',
        () {
      late Router<String> router;

      setUp(() {
        router = Router<String>();

        final admin = router.group('/admin');
        admin.get('/dashboard', 'dashboard');

        final public = router.group('/public');
        public.get('/about', 'about');
      });

      test('when looking up admin route, then it returns admin value', () {
        final adminResult = router.lookup(Method.get, '/admin/dashboard');
        expectLookupResult(adminResult, 'dashboard');
      });

      test('when looking up public route, then it returns public value', () {
        final publicResult = router.lookup(Method.get, '/public/about');
        expectLookupResult(publicResult, 'about');
      });
    });

    group('Given a group with trailing slash and registered path', () {
      late Router<String> router;

      setUp(() {
        router = Router<String>();
        // Group path with trailing slash
        final api = router.group('/api/');
        api.get('/users', 'users');
      });

      test(
          'when looking up route without trailing slash, then it returns the correct value',
          () {
        final result = router.lookup(Method.get, '/api/users');
        expectLookupResult(result, 'users');
      });

      test(
          'when looking up route with trailing slash, then it returns the correct value',
          () {
        final result = router.lookup(Method.get, '/api/users/');
        expectLookupResult(result, 'users');
      });
    });

    group(
        'Given a group with routes registered with and without leading slashes',
        () {
      late Router<String> router;

      setUp(() {
        router = Router<String>();
        final api = router.group('/api');
        // Route with leading slash
        api.get('/users', 'users');
        // Route without leading slash
        api.get('posts', 'posts');
      });

      test(
          'when looking up route registered with leading slash, then it returns correct value',
          () {
        final usersResult = router.lookup(Method.get, '/api/users');
        expectLookupResult(usersResult, 'users');
      });

      test(
          'when looking up route registered without leading slash, then it returns correct value',
          () {
        final postsResult = router.lookup(Method.get, '/api/posts');
        expectLookupResult(postsResult, 'posts');
      });
    });

    test(
        'Given nested parameterized groups with a registered path, '
        'when looking up the deeply nested route with parameter values, '
        'then it returns the correct value with all parameters extracted', () {
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
