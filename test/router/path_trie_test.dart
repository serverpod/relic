import 'package:relic/src/router/normalized_path.dart';
import 'package:relic/src/router/path_trie.dart';
import 'package:test/test.dart';

void main() {
  group('PathTrie<T>', () {
    late PathTrie<int> trie;

    setUp(() {
      trie = PathTrie<int>();
    });

    group('Adding and Looking Up Basic Routes', () {
      test(
          'Given a simple literal path, '
          'when added and looked up, '
          'then returns correct value and empty parameters', () {
        trie.add(NormalizedPath('/users'), 1);
        final result = trie.lookup(NormalizedPath('/users'));
        expect(result, isNotNull);
        expect(result!.value, equals(1));
        expect(result.parameters, isEmpty);
      });

      test(
          'Given a path not added to the trie, '
          'when looked up, '
          'then returns null', () {
        trie.add(NormalizedPath('/users'), 1);
        expect(trie.lookup(NormalizedPath('/posts')), isNull);
      });

      test(
          'Given a path that is only a prefix of an added route, '
          'when looked up, '
          'then returns null', () {
        trie.add(NormalizedPath('/users/profile'), 1);
        expect(trie.lookup(NormalizedPath('/users')), isNull);
      });

      test(
          'Given a path added to the trie, '
          'when a non-matching path segment is looked up, '
          'then returns null', () {
        trie.add(NormalizedPath('/users/profile/settings'), 1);
        expect(trie.lookup(NormalizedPath('/users/profile/other')), isNull);
      });
    });

    group('Parameter Handling', () {
      test(
          'Given a path with one parameter, '
          'when added and looked up with a matching path, '
          'then returns correct value and extracted parameter', () {
        trie.add(NormalizedPath('/users/:id'), 2);
        final result = trie.lookup(NormalizedPath('/users/123'));
        expect(result, isNotNull);
        expect(result!.value, equals(2));
        expect(result.parameters, equals({#id: '123'}));
      });

      test(
          'Given a path with multiple parameters, '
          'when added and looked up with a matching path, '
          'then returns correct value and all extracted parameters', () {
        trie.add(NormalizedPath('/users/:userId/posts/:postId'), 3);
        final result = trie.lookup(NormalizedPath('/users/abc/posts/xyz'));
        expect(result, isNotNull);
        expect(result!.value, equals(3));
        expect(result.parameters, equals({#userId: 'abc', #postId: 'xyz'}));
      });

      test(
          'Given paths with parameters at different levels, '
          'when looked up, '
          'then matches correctly and extracts parameters', () {
        trie.add(NormalizedPath('/:entity/:id'), 1);
        trie.add(NormalizedPath('/users/:id/profile'), 2);

        var result = trie.lookup(NormalizedPath('/posts/456'));
        expect(result, isNotNull);
        expect(result!.value, equals(1));
        expect(result.parameters, equals({#entity: 'posts', #id: '456'}));

        result = trie.lookup(NormalizedPath('/users/789/profile'));
        expect(result, isNotNull);
        expect(result!.value, equals(2));
        expect(result.parameters, equals({#id: '789'}));

        // Should not match the first route if a more specific one exists later
        result = trie.lookup(NormalizedPath('/users/789'));
        expect(
          result,
          isNull,
          reason: 'Should be null as /users/789 does not have a value itself',
        );
      });
    });

    group('Route Precedence', () {
      test(
          'Given both a literal and parameterized route at the same level, '
          'when looking up paths, '
          'then literal segments are prioritized over parameters', () {
        trie.add(NormalizedPath('/users/:id'), 1); // Parameter
        trie.add(NormalizedPath('/users/me'), 2); // Literal

        // Lookup literal
        var result = trie.lookup(NormalizedPath('/users/me'));
        expect(result, isNotNull);
        expect(result!.value, equals(2));
        expect(result.parameters, isEmpty);

        // Lookup parameter
        result = trie.lookup(NormalizedPath('/users/123'));
        expect(result, isNotNull);
        expect(result!.value, equals(1));
        expect(result.parameters, equals({#id: '123'}));
      });
    });

    group('Error Handling', () {
      test(
          'Given a literal route already exists, '
          'when adding the same literal route again, '
          'then throws ArgumentError', () {
        const path = '/path';
        const value1 = 1;
        const value2 = 2;

        // Add initial route
        trie.add(NormalizedPath(path), value1);
        var result = trie.lookup(NormalizedPath(path));
        expect(result!.value, equals(value1));

        // Expect error when adding the same path again
        expect(
          () => trie.add(NormalizedPath(path), value2),
          throwsArgumentError,
          reason: 'Should throw error on duplicate literal path',
        );

        // Verify original route is intact
        result = trie.lookup(NormalizedPath(path));
        expect(
          result!.value,
          equals(value1),
          reason: 'Original route should remain after failed add',
        );
      });

      test(
          'Given a parameterized route already exists, '
          'when adding the same parameterized route again, '
          'then throws ArgumentError', () {
        const path = '/path/:id';
        const value1 = 1;
        const value2 = 2;

        // Add initial route
        trie.add(NormalizedPath(path), value1);
        var result = trie.lookup(NormalizedPath('/path/111'));
        expect(result!.value, equals(value1));
        expect(result.parameters, equals({#id: '111'}));

        // Expect error when adding the same path structure again
        expect(
          () => trie.add(NormalizedPath(path), value2),
          throwsArgumentError,
          reason: 'Should throw error on duplicate parameterized path',
        );

        // Verify original route is intact
        result = trie.lookup(NormalizedPath('/path/222'));
        expect(result!.value, equals(value1));
        expect(
          result.parameters,
          equals({#id: '222'}),
          reason: 'Original route should remain after failed add',
        );
      });

      test(
          'Given a parameterized route exists, '
          'when adding another route with a conflicting parameter name at the same level, '
          'then throws ArgumentError', () {
        // Add initial route
        trie.add(NormalizedPath('/data/:id'), 1);
        var result = trie.lookup(NormalizedPath('/data/aaa'));
        expect(result!.value, equals(1));
        expect(result.parameters.keys.first, equals(#id));

        // Attempt to add route with conflicting parameter name
        expect(
          () => trie.add(NormalizedPath('/data/:key'), 2),
          throwsArgumentError,
          reason: 'Should throw error on conflicting parameter names',
        );

        // Verify the original route is still intact
        result = trie.lookup(NormalizedPath('/data/bbb'));
        expect(result, isNotNull);
        expect(result!.value, equals(1));
        expect(
          result.parameters.keys.first,
          equals(#id),
          reason: 'Original route should remain after failed add',
        );
      });
    });

    group('Edge Cases', () {
      test(
          'Given the root path, '
          'when added and looked up, '
          'then returns correct value and empty parameters', () {
        trie.add(NormalizedPath('/'), 1);
        final result = trie.lookup(NormalizedPath('/'));
        expect(result, isNotNull);
        expect(result!.value, equals(1));
        expect(result.parameters, isEmpty);
      });

      test(
          'Given the root path and another path, '
          'when looked up, '
          'then correctly distinguishes between them', () {
        trie.add(NormalizedPath('/'), 1);
        trie.add(NormalizedPath('/home'), 2);

        var result = trie.lookup(NormalizedPath('/'));
        expect(result!.value, equals(1));

        result = trie.lookup(NormalizedPath('/home'));
        expect(result!.value, equals(2));
      });

      test(
          'Given paths with trailing slashes, '
          'when added and looked up (using NormalizedPath), '
          'then behaves consistently as if slashes were removed', () {
        // NormalizedPath removes trailing slashes (except for '/')
        trie.add(NormalizedPath('/a/b/'), 1); // Will be stored as /a/b

        var result = trie.lookup(NormalizedPath('/a/b'));
        expect(result, isNotNull);
        expect(result!.value, equals(1));

        // Lookup with trailing slash also works because NormalizedPath handles it
        result = trie.lookup(NormalizedPath('/a/b/'));
        expect(result, isNotNull);
        expect(result!.value, equals(1));
      });
    });

    group('Complex Scenarios', () {
      test(
          'Given a mix of literal and parameterized routes at various depths, '
          'when looking up different matching and non-matching paths, '
          'then returns correct values/parameters or null appropriately', () {
        trie.add(NormalizedPath('/api/v1/users/:userId/data'), 1);
        trie.add(NormalizedPath('/api/v1/users/:userId/settings/:settingId'), 2);
        trie.add(NormalizedPath('/api/v1/posts/:postId'), 3);
        trie.add(
          NormalizedPath('/api/v1/posts/latest'),
          4,
        ); // Literal takes precedence

        // Match user data
        var result = trie.lookup(NormalizedPath('/api/v1/users/user123/data'));
        expect(result!.value, 1);
        expect(result.parameters, {#userId: 'user123'});

        // Match user settings
        result = trie.lookup(
          NormalizedPath('/api/v1/users/user456/settings/pref789'),
        );
        expect(result!.value, 2);
        expect(result.parameters, {#userId: 'user456', #settingId: 'pref789'});

        // Match specific post
        result = trie.lookup(NormalizedPath('/api/v1/posts/post999'));
        expect(result!.value, 3);
        expect(result.parameters, {#postId: 'post999'});

        // Match literal 'latest' post
        result = trie.lookup(NormalizedPath('/api/v1/posts/latest'));
        expect(result!.value, 4);
        expect(result.parameters, isEmpty);

        // No match - Missing parameter value
        expect(
          trie.lookup(NormalizedPath('/api/v1/users/data')),
          isNull,
          reason: 'Missing required userId parameter',
        );
        // No match - Prefix only
        expect(
          trie.lookup(NormalizedPath('/api/v1/posts')),
          isNull,
          reason: 'Path is only a prefix, no value at this node',
        );
        // No match - Wrong literal segment
        expect(
          trie.lookup(NormalizedPath('/api/v2/users/user123/data')),
          isNull,
          reason: 'v2 does not match v1',
        );
      });
    });
  });
}
