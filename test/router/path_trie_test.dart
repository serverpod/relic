import 'package:relic/src/router/normalized_path.dart';
import 'package:relic/src/router/path_trie.dart';
import 'package:test/test.dart';

void main() {
  group('PathTrie', () {
    late PathTrie<int> trie;

    setUp(() {
      trie = PathTrie<int>();
    });

    test('should add and lookup a simple literal path', () {
      trie.add(NormalizedPath('/users'), 1);
      final result = trie.lookup(NormalizedPath('/users'));
      expect(result, isNotNull);
      expect(result!.value, equals(1));
      expect(result.parameters, isEmpty);
    });

    test('should return null for non-existent path', () {
      trie.add(NormalizedPath('/users'), 1);
      expect(trie.lookup(NormalizedPath('/posts')), isNull);
    });

    test(
      'should return null for path that is only a prefix of an existing route',
      () {
        trie.add(NormalizedPath('/users/profile'), 1);
        expect(trie.lookup(NormalizedPath('/users')), isNull);
      },
    );

    test('should add and lookup a path with a parameter', () {
      trie.add(NormalizedPath('/users/:id'), 2);
      final result = trie.lookup(NormalizedPath('/users/123'));
      expect(result, isNotNull);
      expect(result!.value, equals(2));
      expect(result.parameters, equals({#id: '123'}));
    });

    test('should add and lookup a path with multiple parameters', () {
      trie.add(NormalizedPath('/users/:userId/posts/:postId'), 3);
      final result = trie.lookup(NormalizedPath('/users/abc/posts/xyz'));
      expect(result, isNotNull);
      expect(result!.value, equals(3));
      expect(result.parameters, equals({#userId: 'abc', #postId: 'xyz'}));
    });

    test('should prioritize literal segments over parameters', () {
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

    test('should handle parameters at different levels', () {
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
      expect(result, isNull);
    });

    test('should throw ArgumentError when adding duplicate literal route', () {
      const path = '/path';
      const value1 = 1;
      const value2 = 2;

      // Add initial route
      trie.add(NormalizedPath(path), value1);
      var result = trie.lookup(NormalizedPath(path));
      expect(result!.value, equals(value1));

      // Expect error when adding the same path again
      expect(() => trie.add(NormalizedPath(path), value2), throwsArgumentError);

      // Verify original route is intact
      result = trie.lookup(NormalizedPath(path));
      expect(result!.value, equals(value1));
    });

    test(
      'should throw ArgumentError when adding duplicate parameterized route',
      () {
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
        );

        // Verify original route is intact
        result = trie.lookup(NormalizedPath('/path/222'));
        expect(result!.value, equals(value1));
        expect(result.parameters, equals({#id: '222'}));
      },
    );

    test(
      'should throw ArgumentError for conflicting parameter names at the same level',
      () {
        // Add initial route
        trie.add(NormalizedPath('/data/:id'), 1);
        var result = trie.lookup(NormalizedPath('/data/aaa'));
        expect(result!.value, equals(1));
        expect(result.parameters.keys.first, equals(#id));

        // Attempt to add route with conflicting parameter name
        expect(
          () => trie.add(NormalizedPath('/data/:key'), 2),
          throwsArgumentError,
        );

        // Verify the original route is still intact
        result = trie.lookup(NormalizedPath('/data/bbb'));
        expect(result, isNotNull);
        expect(result!.value, equals(1));
        expect(result.parameters.keys.first, equals(#id));
      },
    );

    test('should not match if path segments mismatch', () {
      trie.add(NormalizedPath('/users/profile/settings'), 1);
      expect(trie.lookup(NormalizedPath('/users/profile/other')), isNull);
    });

    test('should handle root path', () {
      trie.add(NormalizedPath('/'), 1);
      final result = trie.lookup(NormalizedPath('/'));
      expect(result, isNotNull);
      expect(result!.value, equals(1));
      expect(result.parameters, isEmpty);
    });

    test('should distinguish between root and other paths', () {
      trie.add(NormalizedPath('/'), 1);
      trie.add(NormalizedPath('/home'), 2);

      var result = trie.lookup(NormalizedPath('/'));
      expect(result!.value, equals(1));

      result = trie.lookup(NormalizedPath('/home'));
      expect(result!.value, equals(2));
    });

    test(
      'should handle paths with trailing slashes consistently due to NormalizedBox',
      () {
        // NormalizedPath removes trailing slashes (except for '/')
        trie.add(NormalizedPath('/a/b/'), 1); // Will be stored as /a/b

        var result = trie.lookup(NormalizedPath('/a/b'));
        expect(result, isNotNull);
        expect(result!.value, equals(1));

        result = trie.lookup(
          NormalizedPath('/a/b/'),
        ); // NormalizedPath makes this /a/b
        expect(result, isNotNull);
        expect(result!.value, equals(1));
      },
    );

    test('complex scenario with mixed literals and params', () {
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

      // No match
      expect(
        trie.lookup(NormalizedPath('/api/v1/users/data')),
        isNull,
      ); // Missing param
      expect(
        trie.lookup(NormalizedPath('/api/v1/posts')),
        isNull,
      ); // Prefix only
      expect(
        trie.lookup(NormalizedPath('/api/v2/users/user123/data')),
        isNull,
      ); // Wrong version
    });
  });
}
