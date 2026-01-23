import 'package:relic_core/relic_core.dart';
import 'package:test/test.dart';

void main() {
  group('PathTrie<T>', () {
    late PathTrie<int> trie;

    setUp(() {
      trie = PathTrie<int>();
    });

    group('Adding and Looking Up Basic Routes', () {
      test('Given a simple literal path, '
          'when added and looked up, '
          'then returns correct value and empty parameters', () {
        trie.add(NormalizedPath('/users'), 1);
        final result = trie.lookup(NormalizedPath('/users'));
        expect(result, isNotNull);
        expect(result!.value, equals(1));
        expect(result.parameters, isEmpty);
      });

      test('Given a path not added to the trie, '
          'when looked up, '
          'then returns null', () {
        trie.add(NormalizedPath('/users'), 1);
        expect(trie.lookup(NormalizedPath('/posts')), isNull);
      });

      test('Given a path that is only a prefix of an added route, '
          'when looked up, '
          'then returns null', () {
        trie.add(NormalizedPath('/users/profile'), 1);
        expect(trie.lookup(NormalizedPath('/users')), isNull);
      });

      test('Given a path added to the trie, '
          'when a non-matching path segment is looked up, '
          'then returns null', () {
        trie.add(NormalizedPath('/users/profile/settings'), 1);
        expect(trie.lookup(NormalizedPath('/users/profile/other')), isNull);
      });
    });

    group('Parameter Handling', () {
      test('Given a path with one parameter, '
          'when added and looked up with a matching path, '
          'then returns correct value and extracted parameter', () {
        trie.add(NormalizedPath('/users/:id'), 2);
        final result = trie.lookup(NormalizedPath('/users/123'));
        expect(result, isNotNull);
        expect(result!.value, equals(2));
        expect(result.parameters, equals({#id: '123'}));
      });

      test('Given a path with multiple parameters, '
          'when added and looked up with a matching path, '
          'then returns correct value and all extracted parameters', () {
        trie.add(NormalizedPath('/users/:userId/posts/:postId'), 3);
        final result = trie.lookup(NormalizedPath('/users/abc/posts/xyz'));
        expect(result, isNotNull);
        expect(result!.value, equals(3));
        expect(result.parameters, equals({#userId: 'abc', #postId: 'xyz'}));
      });

      test('Given paths with parameters at different levels, '
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
      });

      test('Given a path with repeated parameters at different levels, '
          'when looked up, '
          'then last extracted parameter wins', () {
        trie.add(NormalizedPath('/:id/:id'), 1);

        final result = trie.lookup(NormalizedPath('/123/456'));
        expect(result, isNotNull);
        expect(result!.value, equals(1));
        expect(result.parameters, equals({#id: '456'}));
      });
    });

    group('Route Precedence', () {
      test('Given both a literal and parameterized route at the same level, '
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

    group('Backtracking', () {
      test('Given overlapping literal and parameter routes, '
          'when literal path fails to match, '
          'then backtracks to try parameter route', () {
        trie.add(NormalizedPath('/:entity/:id'), 1);
        trie.add(NormalizedPath('/users/:id/profile'), 2);

        // /users/789 should now match /:entity/:id via backtracking
        final result = trie.lookup(NormalizedPath('/users/789'));
        expect(result, isNotNull);
        expect(result!.value, equals(1));
        expect(result.parameters, equals({#entity: 'users', #id: '789'}));
      });

      group('Given overlapping routes at multiple levels', () {
        setUp(() {
          trie.add(NormalizedPath('/:a/:b'), 1);
          trie.add(NormalizedPath('/x/:b'), 2);
          trie.add(NormalizedPath('/x/y'), 3);
        });

        test('when exact literal path matches, '
            'then returns the deeper match without backtracking', () {
          final result = trie.lookup(NormalizedPath('/x/y'));
          expect(result, isNotNull);
          expect(result!.value, equals(3));
          expect(result.parameters, isEmpty);
        });

        test('when literal prefix matches then parameter, '
            'then returns the partial literal match', () {
          final result = trie.lookup(NormalizedPath('/x/z'));
          expect(result, isNotNull);
          expect(result!.value, equals(2));
          expect(result.parameters, equals({#b: 'z'}));
        });

        test('when only parameter route matches, '
            'then returns the full parameter match', () {
          final result = trie.lookup(NormalizedPath('/a/b'));
          expect(result, isNotNull);
          expect(result!.value, equals(1));
          expect(result.parameters, equals({#a: 'a', #b: 'b'}));
        });
      });

      test('Given a literal route that leads to dead end, '
          'when backtracking occurs, '
          'then finds alternative parameter route', () {
        trie.add(NormalizedPath('/api/v1/users'), 1);
        trie.add(NormalizedPath('/api/:version/items'), 2);

        // Should match /api/:version/items via backtracking
        final result = trie.lookup(NormalizedPath('/api/v1/items'));
        expect(result, isNotNull);
        expect(result!.value, equals(2));
        expect(result.parameters, equals({#version: 'v1'}));
      });

      test('Given multiple levels of backtracking needed, '
          'when lookup occurs, '
          'then correctly backtracks through all levels', () {
        trie.add(NormalizedPath('/:a/:b/:c'), 1);
        trie.add(NormalizedPath('/x/:b/z'), 2);
        trie.add(NormalizedPath('/x/y/:c'), 3);

        // Needs to backtrack from /x/y to try /x/:b, then to /:a
        final result = trie.lookup(NormalizedPath('/x/y/w'));
        expect(result, isNotNull);
        expect(result!.value, equals(3));
        expect(result.parameters, equals({#c: 'w'}));
      });

      test('Given backtracking scenario with no valid match, '
          'when all paths exhausted, '
          'then returns null', () {
        trie.add(NormalizedPath('/users/:id/profile'), 1);
        trie.add(NormalizedPath('/users/admin/settings'), 2);

        // No route matches /users/admin/profile
        final result = trie.lookup(NormalizedPath('/users/guest/settings'));
        expect(result, isNull);
      });

      test('Given literal priority with successful match, '
          'when literal path succeeds, '
          'then does not consider parameter alternatives', () {
        trie.add(NormalizedPath('/:entity/list'), 1);
        trie.add(NormalizedPath('/users/list'), 2);

        // Should match literal /users/list, not /:entity/list
        final result = trie.lookup(NormalizedPath('/users/list'));
        expect(result, isNotNull);
        expect(result!.value, equals(2));
        expect(result.parameters, isEmpty);
      });

      group('Given tail route and more specific literal route', () {
        setUp(() {
          trie.add(NormalizedPath('/files/**'), 1);
          trie.add(NormalizedPath('/files/special/report'), 2);
        });

        test('when exact literal path matches, '
            'then returns the specific route', () {
          final result = trie.lookup(NormalizedPath('/files/special/report'));
          expect(result, isNotNull);
          expect(result!.value, equals(2));
        });

        test('when literal path fails, '
            'then backtracks to tail route', () {
          final result = trie.lookup(NormalizedPath('/files/special/other'));
          expect(result, isNotNull);
          expect(result!.value, equals(1));
          expect(result.matched.path, equals('/files'));
          expect(result.remaining.path, equals('/special/other'));
        });
      });

      group('Given tail route and literal route with parameter', () {
        setUp(() {
          trie.add(NormalizedPath('/api/**'), 1);
          trie.add(NormalizedPath('/api/v1/:resource/docs'), 2);
        });

        test('when exact literal path with parameter matches, '
            'then returns the specific route', () {
          final result = trie.lookup(NormalizedPath('/api/v1/users/docs'));
          expect(result, isNotNull);
          expect(result!.value, equals(2));
          expect(result.parameters, equals({#resource: 'users'}));
        });

        test('when literal path with parameter fails, '
            'then backtracks to tail route', () {
          final result = trie.lookup(NormalizedPath('/api/v1/users/other'));
          expect(result, isNotNull);
          expect(result!.value, equals(1));
          expect(result.matched.path, equals('/api'));
          expect(result.remaining.path, equals('/v1/users/other'));
        });
      });

      test('Given nested tail routes, '
          'when deeper tail matches, '
          'then returns deeper match', () {
        trie.add(NormalizedPath('/static/**'), 1);
        trie.add(NormalizedPath('/static/assets/**'), 2);

        // Should match deeper tail
        var result = trie.lookup(NormalizedPath('/static/assets/image.png'));
        expect(result, isNotNull);
        expect(result!.value, equals(2));
        expect(result.matched.path, equals('/static/assets'));
        expect(result.remaining.path, equals('/image.png'));

        // Should match shallower tail for non-assets path
        result = trie.lookup(NormalizedPath('/static/other/file.txt'));
        expect(result, isNotNull);
        expect(result!.value, equals(1));
        expect(result.matched.path, equals('/static'));
        expect(result.remaining.path, equals('/other/file.txt'));
      });

      test('Given tail route with literal sibling that has no value, '
          'when literal path partially matches, '
          'then backtracks to tail', () {
        trie.add(NormalizedPath('/app/**'), 1);
        trie.add(NormalizedPath('/app/admin/dashboard'), 2);

        // No route for /app/admin alone, should backtrack to tail
        final result = trie.lookup(NormalizedPath('/app/admin'));
        expect(result, isNotNull);
        expect(result!.value, equals(1));
        expect(result.matched.path, equals('/app'));
        expect(result.remaining.path, equals('/admin'));
      });

      test('Given multiple backtrack points before tail, '
          'when all specific routes fail, '
          'then eventually matches tail', () {
        trie.add(NormalizedPath('/root/**'), 1);
        trie.add(NormalizedPath('/root/a/b/c'), 2);
        trie.add(NormalizedPath('/root/a/:param/d'), 3);

        // Should backtrack through /root/a/b, then /root/a/:param, to /root/**
        final result = trie.lookup(NormalizedPath('/root/a/b/x'));
        expect(result, isNotNull);
        expect(result!.value, equals(1));
        expect(result.matched.path, equals('/root'));
        expect(result.remaining.path, equals('/a/b/x'));
      });
    });

    group('Error Handling', () {
      test('Given a literal route already exists, '
          'when adding the same literal route again, '
          'then throws ArgumentError', () {
        const path = '/path';
        const value1 = 1;
        const value2 = 2;

        // Add initial route
        trie.add(NormalizedPath(path), value1);

        // Expect error when adding the same path again
        expect(
          () => trie.add(NormalizedPath(path), value2),
          throwsArgumentError,
          reason: 'Should throw error on duplicate literal path',
        );

        // Verify original route is intact
        final result = trie.lookup(NormalizedPath(path));
        expect(
          result!.value,
          equals(value1),
          reason: 'Original route should remain after failed add',
        );
      });

      test('Given a parameterized route already exists, '
          'when adding the same parameterized route again, '
          'then throws ArgumentError', () {
        const path = '/path/:id';
        const value1 = 1;
        const value2 = 2;

        // Add initial route
        trie.add(NormalizedPath(path), value1);
        var result = trie.lookup(NormalizedPath('/path/111'));

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

      test('Given a parameterized route exists, '
          'when adding another route with a conflicting parameter name at the same level, '
          'then throws ArgumentError', () {
        // Add initial route
        trie.add(NormalizedPath('/data/:id'), 1);
        var result = trie.lookup(NormalizedPath('/data/aaa'));

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

      test('Given a normalizedPath with an unnamed parameter, '
          'when trying to add to a trie, '
          'then it fails ', () {
        expect(() => trie.add(NormalizedPath('/:'), 1), throwsArgumentError);
      });
    });

    group('Edge Cases', () {
      test('Given the root path, '
          'when added and looked up, '
          'then returns correct value and empty parameters', () {
        trie.add(NormalizedPath('/'), 1);
        final result = trie.lookup(NormalizedPath('/'));
        expect(result, isNotNull);
        expect(result!.value, equals(1));
        expect(result.parameters, isEmpty);
      });

      test('Given the root path and another path, '
          'when looked up, '
          'then correctly distinguishes between them', () {
        trie.add(NormalizedPath('/'), 1);
        trie.add(NormalizedPath('/home'), 2);

        var result = trie.lookup(NormalizedPath('/'));
        expect(result!.value, equals(1));

        result = trie.lookup(NormalizedPath('/home'));
        expect(result!.value, equals(2));
      });

      test('Given paths with trailing slashes, '
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
      test('Given a mix of literal and parameterized routes at various depths, '
          'when looking up different matching and non-matching paths, '
          'then returns correct values/parameters or null appropriately', () {
        trie.add(NormalizedPath('/api/v1/users/:userId/data'), 1);
        trie.add(
          NormalizedPath('/api/v1/users/:userId/settings/:settingId'),
          2,
        );
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

    group('Attaching Tries', () {
      late PathTrie<int> trieA;
      late PathTrie<int> trieB;

      setUp(() {
        trieA = PathTrie<int>();
        trieB = PathTrie<int>();
      });

      test('Given two tries, one with a route, '
          'when the second trie is attached to the first, '
          'then routes from the second trie are accessible via the first', () {
        // Setup trieB
        trieB.add(NormalizedPath('/routeB'), 10);

        // Attach trieB to trieA
        trieA.attach(NormalizedPath('/pathA'), trieB);

        // Lookup in trieA
        final result = trieA.lookup(NormalizedPath('/pathA/routeB'));
        expect(result, isNotNull);
        expect(result!.value, equals(10));
        expect(result.parameters, isEmpty);
      });

      test('Given an empty trie, '
          'when attempting to attach another trie at the root path ("/"), '
          'then it succeeds', () {
        expect(() => trieA.attach(NormalizedPath('/'), trieB), returnsNormally);
      });

      test('Given a trie with an existing path, '
          'when attempting to attach another trie on a sub-path, '
          'then it succeeds and both tries are updated', () {
        trieA.add(NormalizedPath('/pathA/existing/A'), 1);
        trieB.add(NormalizedPath('/pathB/'), 2);

        expect(
          () => trieA.attach(NormalizedPath('/pathA/existing'), trieB),
          returnsNormally,
        );

        // We can see B in A ..
        var result = trieA.lookup(NormalizedPath('/pathA/existing/pathB'));
        expect(result, isNotNull);
        expect(result!.value, equals(2));

        // .. but we can also see part of A in B
        result = trieB.lookup(NormalizedPath('/A'));
        expect(result, isNotNull);
        expect(result!.value, equals(1));
      });

      test('Given a trie with an existing path, '
          'when attempting to attach another trie at that same path that, '
          'then it fails', () {
        trieA.add(NormalizedPath('/existing'), 1);
        trieB.add(NormalizedPath('/'), 2);
        expect(
          () => trieA.attach(NormalizedPath('/existing'), trieB),
          throwsA(
            isA<ArgumentError>().having(
              (final e) => e.message,
              'message',
              equals('Conflicting values'),
            ),
          ),
        );
      });

      test('Given a trie with an existing parameterized path, '
          'when attempting to attach another trie with a parameterized root path at that level'
          'then it fails due to conflicting parameters', () {
        trieA.add(NormalizedPath('/existing/:a'), 1);
        trieB.add(NormalizedPath('/:b'), 2);
        expect(
          () => trieA.attach(NormalizedPath('/existing'), trieB),
          throwsA(
            isA<ArgumentError>().having(
              (final e) => e.message,
              'message',
              equals('Conflicting parameters'),
            ),
          ),
        );
      });

      test('Given a trie with an existing path, '
          'when attempting to attach another trie such that children names would overlap, '
          'then it fails due to conflicting children', () {
        trieA.add(NormalizedPath('/existing/foo'), 1);
        trieB.add(NormalizedPath('/foo'), 2);
        expect(
          () => trieA.attach(NormalizedPath('/existing'), trieB),
          throwsA(
            isA<ArgumentError>().having(
              (final e) => e.message,
              'message',
              equals('Conflicting children'),
            ),
          ),
        );
      });

      test('Given trie B attached to trie A, '
          'when trie B is updated with a new route after attachment, '
          'then the new route is accessible via trie A', () {
        // Initial setup and attachment
        trieB.add(NormalizedPath('/route1'), 10);
        trieA.attach(NormalizedPath('/prefixB'), trieB);

        // Add new route to trieB *after* attachment
        trieB.add(NormalizedPath('/route2'), 20);

        // Verify new route is accessible via trieA
        final result = trieA.lookup(NormalizedPath('/prefixB/route2'));
        expect(result, isNotNull);
        expect(result!.value, equals(20));
      });

      test('Given trie B with parameterized routes attached to trie A, '
          'when looking up paths in trie A that extend into trie B, '
          'then parameters from trieB are correctly resolved', () {
        // Setup trieB with a parameterized route
        trieB.add(NormalizedPath('/items/:itemId'), 100);
        trieA.attach(NormalizedPath('/api'), trieB); // Attach trieB at /api

        // Lookup a path that goes through trieA into trieB
        final result = trieA.lookup(NormalizedPath('/api/items/abc'));
        expect(result, isNotNull);
        expect(result!.value, equals(100));
        expect(result.parameters, equals({#itemId: 'abc'}));
      });

      test(
        'Given trie B with parameterized routes attached to trie A under a parameterized route, '
        'when looking up paths in trie A that extend into trie B, '
        'then parameters from both tries are correctly resolved',
        () {
          // More complex scenario: trieA has parameters, trieB is attached under that
          trieB.add(NormalizedPath('/:paramB/endpoint'), 300);
          trieA.add(NormalizedPath('/users/:userId'), 200); // A route in trieA
          trieA.attach(NormalizedPath('/users/:userId/data'), trieB);

          // Lookup path spanning trieA (with param) and trieB (with param)
          final result = trieA.lookup(
            NormalizedPath('/users/user123/data/val456/endpoint'),
          );
          expect(
            result,
            isNotNull,
            reason: 'Should find path through attached trieB',
          );
          expect(result!.value, equals(300));
          expect(
            result.parameters,
            equals({#userId: 'user123', #paramB: 'val456'}),
          );
        },
      );

      test(
        'Given a path with repeated parameters at different levels introduced by attach, '
        'when looked up, '
        'then last extracted parameter wins',
        () {
          trieA.add(NormalizedPath('/:id/'), 1);
          trieB.add(NormalizedPath('/:id/'), 2);
          trieA.attach(NormalizedPath('/:id/'), trieB);

          final result = trieA.lookup(NormalizedPath('/123/456'));
          expect(result, isNotNull);
          expect(result!.value, equals(2));
          expect(result.parameters, equals({#id: '456'}));
        },
      );

      test('Given a trie attached at a tail path with consume: true, '
          'when the attached trie is a single value trie, '
          'then it succeeds and the value is accessible', () {
        trieB.add(NormalizedPath('/'), 1);

        // Should succeed because trieB is a single value trie
        expect(
          () => trieA.attach(NormalizedPath('/files/**'), trieB, consume: true),
          returnsNormally,
        );

        // The attached value should be accessible via the tail path
        final result = trieA.lookup(NormalizedPath('/files/any/path'));
        expect(result, isNotNull);
        expect(result!.value, equals(1));
        expect(result.matched.path, equals('/files'));
        expect(result.remaining.path, equals('/any/path'));
      });

      test('Given a trie attached with consume: true, '
          'when a new path is added to the consumed trie, '
          'then it is not visible in the parent trie', () {
        trieB.add(NormalizedPath('/'), 1);
        trieA.attach(NormalizedPath('/api'), trieB, consume: true);

        // Add a new route to trieB after attachment
        trieB.add(NormalizedPath('/new'), 2);

        // The new route should NOT be visible in trieA
        final result = trieA.lookup(NormalizedPath('/api/new'));
        expect(result, isNull);

        // But the original route should still be accessible
        final originalResult = trieA.lookup(NormalizedPath('/api'));
        expect(originalResult, isNotNull);
        expect(originalResult!.value, equals(1));
      });

      test('Given a trie attached at a tail path with consume: true, '
          'when the attached trie is not a single value trie, '
          'then it throws an ArgumentError', () {
        trieB.add(NormalizedPath('/'), 1);
        trieB.add(NormalizedPath('/child'), 2);

        // Should fail because trieB is not a single value trie
        expect(
          () => trieA.attach(NormalizedPath('/files/**'), trieB, consume: true),
          throwsArgumentError,
        );
      });
    });

    group('Path Enumeration', () {
      test('Given an empty trie, '
          'when paths is accessed, '
          'then returns an empty iterable', () {
        expect(trie.paths, isEmpty);
      });

      test('Given an empty trie, '
          'when toString is called, '
          'then returns "PathTrie (empty)"', () {
        expect(trie.toString(), equals('PathTrie (empty)'));
      });

      test('Given a trie with only a root path, '
          'when paths is accessed, '
          'then returns a list containing only "/"', () {
        trie.add(NormalizedPath('/'), 1);
        expect(trie.paths.toList(), equals(['/']));
      });

      test('Given a trie with multiple literal paths, '
          'when paths is accessed, '
          'then returns paths sorted alphabetically', () {
        trie.add(NormalizedPath('/zebra'), 1);
        trie.add(NormalizedPath('/apple'), 2);
        trie.add(NormalizedPath('/mango'), 3);

        expect(trie.paths.toList(), equals(['/apple', '/mango', '/zebra']));
      });

      test('Given a trie with parameter segments, '
          'when paths is accessed, '
          'then returns paths with :paramName format', () {
        trie.add(NormalizedPath('/users/:id'), 1);
        trie.add(NormalizedPath('/users/:id/posts/:postId'), 2);

        expect(
          trie.paths.toList(),
          equals(['/users/:id', '/users/:id/posts/:postId']),
        );
      });

      test('Given a trie with wildcard segments, '
          'when paths is accessed, '
          'then returns paths with * format', () {
        trie.add(NormalizedPath('/files/*'), 1);
        trie.add(NormalizedPath('/files/*/info'), 2);

        expect(trie.paths.toList(), equals(['/files/*', '/files/*/info']));
      });

      test('Given a trie with tail segments, '
          'when paths is accessed, '
          'then returns paths with ** format', () {
        trie.add(NormalizedPath('/static/**'), 1);
        trie.add(NormalizedPath('/assets/**'), 2);

        expect(trie.paths.toList(), equals(['/assets/**', '/static/**']));
      });

      test('Given a trie with mixed segment types, '
          'when paths is accessed, '
          'then returns paths with literals before dynamic segments', () {
        trie.add(NormalizedPath('/api/users/:id'), 1);
        trie.add(NormalizedPath('/api/posts'), 2);
        trie.add(NormalizedPath('/static/**'), 3);

        expect(
          trie.paths.toList(),
          equals(['/api/posts', '/api/users/:id', '/static/**']),
        );
      });

      test('Given a trie with intermediate nodes without values, '
          'when paths is accessed, '
          'then only returns paths with values', () {
        // Only /users/:id/profile has a value, not /users or /users/:id
        trie.add(NormalizedPath('/users/:id/profile'), 1);

        expect(trie.paths.toList(), equals(['/users/:id/profile']));
      });

      test('Given a trie with deep nesting, '
          'when paths is accessed, '
          'then returns all nested paths correctly', () {
        trie.add(NormalizedPath('/a/b/c/d'), 1);
        trie.add(NormalizedPath('/a/b/c'), 2);
        trie.add(NormalizedPath('/a/b'), 3);
        trie.add(NormalizedPath('/a'), 4);

        expect(
          trie.paths.toList(),
          equals(['/a', '/a/b', '/a/b/c', '/a/b/c/d']),
        );
      });

      test('Given a trie with toString called, '
          'when trie has multiple paths, '
          'then returns formatted string with all paths', () {
        trie.add(NormalizedPath('/users'), 1);
        trie.add(NormalizedPath('/posts'), 2);

        expect(trie.toString(), equals('PathTrie:\n  /posts\n  /users'));
      });

      group('Cycle Detection', () {
        late PathTrie<int> trieA;
        late PathTrie<int> trieB;

        setUp(() {
          trieA = PathTrie<int>();
          trieB = PathTrie<int>();
        });

        test('Given a trie attached to itself, '
            'when paths is accessed, '
            'then completes without infinite loop', () {
          trieA.add(NormalizedPath('/a'), 1);
          trieA.attach(NormalizedPath('/a'), trieA);

          // After self-attachment, trieA._root points to the /a node
          // So the root now has the value, and path enumeration sees it as '/'
          // This would hang if cycle detection wasn't working
          final paths = trieA.paths.toList();
          expect(paths, contains('/'));
        });

        test('Given two tries attached to each other creating a cycle, '
            'when paths is accessed on either, '
            'then completes without infinite loop', () {
          trieA.add(NormalizedPath('/pathA'), 1);
          trieB.add(NormalizedPath('/pathB'), 2);

          // Create mutual attachment
          trieA.attach(NormalizedPath('/pathA'), trieB);

          // Now trieB's root points to /pathA in trieA
          // Adding to trieB adds to trieA as well
          // This creates a potential cycle when iterating

          final pathsA = trieA.paths.toList();
          expect(pathsA, contains('/pathA'));
          expect(pathsA, contains('/pathA/pathB'));
        });
      });

      group('DOT Graph Output', () {
        test('Given an empty trie, '
            'when toDot is called, '
            'then returns valid DOT with single root node', () {
          final dot = trie.toDot();
          expect(dot, contains('digraph PathTrie {'));
          expect(dot, contains('n0 [shape=circle'));
          expect(dot, endsWith('}\n'));
        });

        test('Given a trie with a root value, '
            'when toDot is called, '
            'then root node has doublecircle shape', () {
          trie.add(NormalizedPath('/'), 42);
          final dot = trie.toDot();
          expect(dot, contains('n0 [shape=doublecircle, label="42"]'));
        });

        test('Given a trie with literal paths, '
            'when toDot is called, '
            'then shows edges with segment labels', () {
          trie.add(NormalizedPath('/users'), 1);
          trie.add(NormalizedPath('/posts'), 2);
          final dot = trie.toDot();
          expect(dot, contains('-> n1 [label="posts"]'));
          expect(dot, contains('-> n2 [label="users"]'));
        });

        test('Given a trie with parameter segments, '
            'when toDot is called, '
            'then shows :paramName in edge labels', () {
          trie.add(NormalizedPath('/users/:id'), 1);
          final dot = trie.toDot();
          expect(dot, contains('[label=":id"]'));
        });

        test('Given a trie with wildcard segments, '
            'when toDot is called, '
            'then shows * in edge labels', () {
          trie.add(NormalizedPath('/files/*'), 1);
          final dot = trie.toDot();
          expect(dot, contains('[label="*"]'));
        });

        test('Given a trie with tail segments, '
            'when toDot is called, '
            'then shows ** in edge labels', () {
          trie.add(NormalizedPath('/static/**'), 1);
          final dot = trie.toDot();
          expect(dot, contains('[label="**"]'));
        });

        test('Given a trie with a cycle from self-attachment, '
            'when toDot is called, '
            'then shows cycle as dashed red edge', () {
          final trieA = PathTrie<int>();
          trieA.add(NormalizedPath('/a'), 1);
          trieA.add(NormalizedPath('/a/b'), 2);
          trieA.attach(NormalizedPath('/a/b'), trieA);

          final dot = trieA.toDot();
          // The cycle edge should be dashed and red
          expect(dot, contains('style=dashed, color=red'));
        });
      });
    });
  });
}
