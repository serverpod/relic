import 'package:relic/src/router/path_trie.dart';
import 'package:relic/src/router/router.dart';
import 'package:test/test.dart';

void main() {
  // Helper to check LookupResult - remains the same
  void expectLookupResult(
    final LookupResult<String>? actual,
    final String expectedValue, [
    final Map<Symbol, String> expectedParams = const {},
  ]) {
    expect(actual, isNotNull);
    expect(actual?.value, equals(expectedValue));
    expect(actual?.parameters, equals(expectedParams));
  }

  group('Given an empty Router', () {
    late Router<String> router;
    setUp(() {
      router = Router<String>();
    });

    test(
        'when looking up an empty string, '
        'then it should return null', () {
      final result = router.lookup('');
      expect(result, isNull);
    });

    test(
        'when looking up a non-empty string, '
        'then it should return null', () {
      final result = router.lookup('/hello');
      expect(result, isNull);
    });

    test(
        'when looking up the root path "/", '
        'then it should return null', () {
      final result = router.lookup('/');
      expect(result, isNull);
    });

    test(
        'when adding the root path "/", '
        'then lookup for "/" should return the correct value', () {
      router.add('/', 'root_handler');
      final result = router.lookup('/');
      expectLookupResult(result, 'root_handler');
    });

    test(
        'when adding an empty string path, '
        'then lookup for "/" should return the correct value', () {
      router.add('', 'empty_string_handler');
      final result = router.lookup('/');
      expectLookupResult(result, 'empty_string_handler');
    });

    test(
        'when adding an empty string path, '
        'then lookup for "" should return the correct value', () {
      router.add('', 'empty_string_handler');
      final result = router.lookup('');
      expectLookupResult(result, 'empty_string_handler');
    });
  });

  group('Given a Router with a simple static route added', () {
    late Router<String> router;
    const path = '/hello';
    const value = 'hello_handler';

    setUp(() {
      router = Router<String>();
      router.add(path, value);
    });

    test(
        'when looking up the exact path, '
        'then it should return the correct value', () {
      final result = router.lookup(path);
      expectLookupResult(result, value);
    });

    test(
        'when looking up the path with a trailing slash, '
        'then it should return the correct value', () {
      final result = router.lookup('$path/');
      expectLookupResult(result, value);
    });

    test(
        'when looking up a different path, '
        'then it should return null', () {
      final result = router.lookup('/world');
      expect(result, isNull);
    });
  });

  group('Given a Router with a multi-segment static route added', () {
    late Router<String> router;
    const path = '/admin/users/list';
    const value = 'admin_users_list';

    setUp(() {
      router = Router<String>();
      router.add(path, value);
    });

    test(
        'when looking up the exact path, '
        'then it should return the correct value', () {
      final result = router.lookup(path);
      expectLookupResult(result, value);
    });

    test(
        'when looking up a prefix of the path, '
        'then it should return null', () {
      final result = router.lookup('/admin/users');
      expect(result, isNull);
    });
  });

  group('Given a Router with a static route added with a trailing slash', () {
    late Router<String> router;
    const pathWithSlash = '/static/path/';
    const pathWithoutSlash = '/static/path';
    const value = 'static_handler';

    setUp(() {
      router = Router<String>();
      router.add(pathWithSlash, value);
    });

    test(
        'when looking up the path without the slash, '
        'then it should return the correct value', () {
      final result = router.lookup(pathWithoutSlash);
      expectLookupResult(result, value);
    });

    test(
        'when looking up the path with the slash, '
        'then it should return the correct value', () {
      final result = router.lookup(pathWithSlash);
      expectLookupResult(result, value);
    });
  });

  group(
    'Given a Router with a static route added without a trailing slash',
    () {
      late Router<String> router;
      const pathWithSlash = '/static/path/';
      const pathWithoutSlash = '/static/path';
      const value = 'static_handler';

      setUp(() {
        router = Router<String>();
        router.add(pathWithoutSlash, value);
      });

      test(
          'when looking up the path without the slash, '
          'then it should return the correct value', () {
        final result = router.lookup(pathWithoutSlash);
        expectLookupResult(result, value);
      });

      test(
          'when looking up the path with the slash '
          'then it should return the correct value', () {
        final result = router.lookup(pathWithSlash);
        expectLookupResult(result, value);
      });
    },
  );

  group('Given a Router with a static route added', () {
    late Router<String> router;
    const path = '/duplicate';
    const firstValue = 'first_value';
    const secondValue = 'second_value';

    setUp(() {
      router = Router<String>();
      router.add(path, firstValue);
    });

    test(
        'when adding the same path again, '
        'then it should throw ArgumentError and retain the original value', () {
      // Check that the first value is present
      var result = router.lookup(path);
      expectLookupResult(result, firstValue);

      // Expect an error when adding the same path again
      expect(() => router.add(path, secondValue), throwsArgumentError);

      // Verify the original route is still intact with the first value
      result = router.lookup(path);
      expectLookupResult(result, firstValue);
    });

    test(
        'when adding a path that normalizes to the same path '
        'then it should throw ArgumentError', () {
      const equivalentPath = '$path/'; // Normalizes to the same as path
      expect(
        () => router.add(equivalentPath, secondValue),
        throwsArgumentError,
      );
    });
  });

  group('Given a Router with a single-parameter dynamic route', () {
    late Router<String> router;
    const pattern = '/users/:id';
    const value = 'user_handler';
    setUp(() {
      router = Router<String>();
      router.add(pattern, value);
    });

    test(
        'when looking up a matching path, '
        'then it should return the value and parameter', () {
      final result = router.lookup('/users/123');
      expectLookupResult(result, value, {#id: '123'});
    });

    test(
        'when looking up a non-matching path structure, '
        'then it should return null', () {
      final result = router.lookup('/posts/123');
      expect(result, isNull);
    });

    test(
        'when looking up a path matching only the prefix, '
        'then it should return null', () {
      final result = router.lookup('/users');
      expect(result, isNull);
    });
  });

  group('Given a Router with a root-level parameter dynamic route', () {
    late Router<String> router;
    const pattern = '/:filename';
    const value = 'file_handler';
    setUp(() {
      router = Router<String>();
      router.add(pattern, value);
    });

    test(
        'when looking up a matching path, '
        'then it should return the value and parameter', () {
      final result = router.lookup('/report.pdf');
      expectLookupResult(result, value, {#filename: 'report.pdf'});
    });

    test(
        'when looking up the root path "/", '
        'then it should return null', () {
      final result = router.lookup('/');
      expect(result, isNull);
    });
  });

  group('Given a Router with a multi-parameter dynamic route', () {
    late Router<String> router;
    const pattern = '/users/:userId/items/:itemId';
    const value = 'item_handler';
    setUp(() {
      router = Router<String>();
      router.add(pattern, value);
    });

    test(
        'when looking up a matching path, '
        'then it should return the value and parameters', () {
      final result = router.lookup('/users/abc/items/xyz');
      expectLookupResult(result, value, {#userId: 'abc', #itemId: 'xyz'});
    });

    test(
        'when looking up a path matching only the first parameter section, '
        'then it should return null', () {
      final result = router.lookup('/users/abc');
      expect(result, isNull);
    });

    test(
      'when looking up a path matching the first parameter section and part of the literal '
      'then it should return null',
      () {
        final result = router.lookup('/users/abc/items');
        expect(result, isNull);
      },
    );
  });

  group(
    'Given a Router with multiple dynamic routes with parameters at different positions',
    () {
      late Router<String> router;
      setUp(() {
        router = Router<String>();
        router.add('/products/:productId/details', 'product_details');
        router.add('/products/:productId/reviews/:reviewId', 'product_review');
      });

      test(
          'when looking up the details route, '
          'then it should match correctly', () {
        final result = router.lookup('/products/p100/details');
        expectLookupResult(result, 'product_details', {#productId: 'p100'});
      });

      test(
          'when looking up the reviews route, '
          'then it should match correctly', () {
        final result = router.lookup('/products/p200/reviews/r50');
        expectLookupResult(result, 'product_review', {
          #productId: 'p200',
          #reviewId: 'r50',
        });
      });
    },
  );

  group(
    'Given a Router with dynamic routes having different initial literal segments',
    () {
      late Router<String> router;
      const userPattern = '/users/:id';
      const userValue = 'user_val';
      const postPattern = '/posts/:postId';
      const postValue = 'post_val';

      setUp(() {
        router = Router<String>();
        // Add two routes where the first segment ('users' vs 'posts') differs
        router.add(userPattern, userValue);
        router.add(postPattern, postValue);
      });

      test(
          'when looking up the first pattern, '
          'then it should match correctly', () {
        final result = router.lookup('/users/1');
        expectLookupResult(result, userValue, {#id: '1'});
      });

      test(
          'when looking up the second pattern '
          'then it should match correctly', () {
        final result = router.lookup('/posts/abc');
        expectLookupResult(result, postValue, {#postId: 'abc'});
      });

      test(
          'when looking up a different initial segment '
          'then it should return null', () {
        final result = router.lookup('/articles/xyz');
        expect(result, isNull);
      });
    },
  );

  group('Given a Router with a dynamic route added with a trailing slash', () {
    late Router<String> router;
    const patternWithSlash = '/dynamic/:param/';
    const pathWithoutSlash = '/dynamic/value1';
    const pathWithSlash = '/dynamic/value1/';
    const value = 'dynamic_handler';

    setUp(() {
      router = Router<String>();
      router.add(patternWithSlash, value);
    });

    test(
        'when looking up without trailing slash '
        'then it should match', () {
      final result = router.lookup(pathWithoutSlash);
      expectLookupResult(result, value, {#param: 'value1'});
    });

    test(
        'when looking up with trailing slash '
        'then it should match', () {
      final result = router.lookup(pathWithSlash);
      expectLookupResult(result, value, {#param: 'value1'});
    });
  });

  group(
    'Given a Router with a dynamic route added without a trailing slash',
    () {
      late Router<String> router;
      const patternWithoutSlash = '/dynamic/:param';
      const pathWithoutSlash = '/dynamic/value2';
      const pathWithSlash = '/dynamic/value2/';
      const value = 'dynamic_handler';

      setUp(() {
        router = Router<String>();
        router.add(patternWithoutSlash, value);
      });

      test(
          'when looking up without trailing slash '
          'then it should match', () {
        final result = router.lookup(pathWithoutSlash);
        expectLookupResult(result, value, {#param: 'value2'});
      });

      test(
          'when looking up with trailing slash '
          'then it should match', () {
        final result = router.lookup(pathWithSlash);
        expectLookupResult(result, value, {#param: 'value2'});
      });
    },
  );

  group('Given a Router with a dynamic route added', () {
    late Router<String> router;
    const path = '/items/:itemId';
    const value1 = 'first_item_handler';
    const value2 = 'second_item_handler';

    setUp(() {
      router = Router<String>();
      router.add(path, value1);
    });

    test(
        'when adding the same dynamic path again '
        'then it should throw ArgumentError and retain original', () {
      // Check original is present
      var result = router.lookup('/items/111');
      expectLookupResult(result, value1, {#itemId: '111'});

      // Expect error when adding the same path again
      expect(() => router.add(path, value2), throwsArgumentError);

      // Verify original route is still intact
      result = router.lookup('/items/222');
      expectLookupResult(result, value1, {#itemId: '222'});
    });
  });

  group(
    'Given a Router where dynamic routes with different parameter names are added at the same level',
    () {
      late Router<String> router;
      const pathId = '/content/:id';
      const pathSlug = '/content/:slug';
      const valueId = 'content_by_id';
      const valueSlug = 'content_by_slug';

      setUp(() {
        router = Router<String>();
        router.add(pathId, valueId);
      });

      test(
          'when adding a conflicting dynamic route '
          'then it should throw ArgumentError and retain original', () {
        // Check original is present
        var result = router.lookup('/content/123');
        expectLookupResult(result, valueId, {#id: '123'});

        // Expect error on adding conflicting route
        expect(() => router.add(pathSlug, valueSlug), throwsArgumentError);

        // Verify original route is still intact
        result = router.lookup('/content/456');
        expectLookupResult(result, valueId, {#id: '456'});
      });
    },
  );

  group('Given a Router with conflicting static and dynamic routes', () {
    late Router<String> router;
    setUp(() {
      router = Router<String>();
      router.add('/users/profile', 'static_profile'); // Static
      router.add('/users/:id', 'dynamic_user'); // Dynamic
    });

    test(
        'when looking up the exact static path '
        'then the static route should be prioritized', () {
      final result = router.lookup('/users/profile');
      expectLookupResult(result, 'static_profile');
    });

    test(
        'when looking up a path matching the dynamic pattern '
        'then the dynamic route should be used', () {
      final result = router.lookup('/users/other');
      expectLookupResult(result, 'dynamic_user', {#id: 'other'});
    });
  });

  group('Given a Router with static and dynamic routes at the same level', () {
    late Router<String> router;
    setUp(() {
      router = Router<String>();
      router.add('/data/latest', 'static_latest'); // Static
      router.add('/data/:version', 'dynamic_version'); // Dynamic
    });

    test(
        'when looking up the static path '
        'then it should match the static route', () {
      final result = router.lookup('/data/latest');
      expectLookupResult(result, 'static_latest');
    });

    test(
        'when looking up a path matching the dynamic pattern '
        'then it should match the dynamic route', () {
      final result = router.lookup('/data/v1.2');
      expectLookupResult(result, 'dynamic_version', {#version: 'v1.2'});
    });
  });

  group('Given a Router with only static routes defined', () {
    late Router<String> router;
    setUp(() {
      router = Router<String>();
      router.add('/static1', 's1');
      router.add('/static2/path', 's2');
    });

    test(
        'when looking up a path that looks dynamic '
        'then it should return null', () {
      final result = router.lookup('/static1/123');
      expect(result, isNull);
    });
  });

  group('Given a Router with only dynamic routes defined', () {
    late Router<String> router;
    setUp(() {
      router = Router<String>();
      router.add('/dynamic/:id', 'd1');
      router.add('/another/:key/value', 'd2');
    });

    test(
        'when looking up a static path, '
        'then it should return null', () {
      final result = router.lookup('/static/path');
      expect(result, isNull);
    });
  });

  group('Given a Router where routes were added with inconsistent slashes', () {
    late Router<String> router;
    setUp(() {
      router = Router<String>();
      // Given: Add paths with different slash variations
      router.add('path1', 'handler1'); // No leading/trailing
      router.add('/path2', 'handler2'); // Leading only
      router.add('path3/', 'handler3'); // Trailing only
      router.add('/path4/', 'handler4'); // Leading and trailing
      router.add('/users/:id/items', 'handler5'); // Dynamic without trailing
      router.add('/posts/:postId/', 'handler6'); // Dynamic with trailing
    });

    test(
        'when looking up paths with various slash combinations '
        'then normalization should ensure correct matches', () {
      expectLookupResult(router.lookup('/path1'), 'handler1');
      expectLookupResult(router.lookup('/path2'), 'handler2');
      expectLookupResult(router.lookup('/path3'), 'handler3');
      expectLookupResult(router.lookup('/path4'), 'handler4');
      expectLookupResult(router.lookup('/users/abc/items'), 'handler5', {
        #id: 'abc',
      });
      expectLookupResult(router.lookup('/posts/xyz'), 'handler6', {
        #postId: 'xyz',
      });

      expectLookupResult(router.lookup('path1'), 'handler1');
      expectLookupResult(router.lookup('path2/'), 'handler2');
      expectLookupResult(router.lookup('/path3/'), 'handler3');
      expectLookupResult(router.lookup('path4'), 'handler4');
      expectLookupResult(router.lookup('/users/abc/items/'), 'handler5', {
        #id: 'abc',
      });
      expectLookupResult(router.lookup('/posts/xyz/'), 'handler6', {
        #postId: 'xyz',
      });
    });
  });

  group('Given two Router instances (mainRouter & subRouter)', () {
    late Router<String> mainRouter;
    late Router<String> subRouter;

    setUp(() {
      mainRouter = Router<String>();
      subRouter = Router<String>();
    });

    group('when a sub-router with routes is attached under /parent', () {
      setUp(() {
        subRouter.add('/child', 'child_handler');
        subRouter.add(
            '', 'sub_root_handler'); // Handler at the root of subRouter
        mainRouter.attach('/parent', subRouter);
      });

      test('then its /child route is accessible via /parent/child', () {
        expectLookupResult(mainRouter.lookup('/parent/child'), 'child_handler');
      });

      test(
          'then its /child route (trailing slash) is accessible via /parent/child/',
          () {
        expectLookupResult(
            mainRouter.lookup('/parent/child/'), 'child_handler');
      });

      test('then its root route is accessible via /parent', () {
        expectLookupResult(mainRouter.lookup('/parent'), 'sub_root_handler');
      });

      test('then its root route (trailing slash) is accessible via /parent/',
          () {
        expectLookupResult(mainRouter.lookup('/parent/'), 'sub_root_handler');
      });

      test('then a non-existent sub-route (/parent/nonexistent) returns null',
          () {
        expect(mainRouter.lookup('/parent/nonexistent'), isNull);
      });
    });

    test(
        'when a sub-route conflicts with an existing direct route, '
        'then it throws and original route remains', () {
      mainRouter.add('/parent/existing_child', 'direct_child_handler_on_main');
      subRouter.add('/existing_child', 'sub_router_child_handler');

      expect(
        () => mainRouter.attach('/parent', subRouter),
        throwsArgumentError,
        reason: 'This would create a conflict at /parent/existing_child',
      );

      // Ensure the original direct route on mainRouter is preserved
      expectLookupResult(mainRouter.lookup('/parent/existing_child'),
          'direct_child_handler_on_main');
    });
  });
}
