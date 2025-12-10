import 'package:relic_core/relic_core.dart';
import 'package:test/test.dart';

void main() {
  group('PathTrie CRUD operations', () {
    late PathTrie<int> trie;

    setUp(() {
      trie = PathTrie<int>();
    });

    group('addOrUpdate', () {
      test('Given an empty trie, '
          'when a new path is added with addOrUpdate, '
          'then the path is added', () {
        final path = NormalizedPath('/users');
        const value = 1;

        final wasAdded = trie.addOrUpdate(path, value);

        final result = trie.lookup(path);
        expect(wasAdded, isTrue);
        expect(result, isNotNull);
        expect(result!.value, equals(value));
        expect(result.parameters, isEmpty);
      });

      test('Given a trie with an existing path, '
          'when addOrUpdate is called for the same path with a new value, '
          'then the value is updated', () {
        final path = NormalizedPath('/users');
        const initialValue = 1;
        const updatedValue = 2;
        trie.add(path, initialValue); // Pre-populate using standard add

        final wasAdded = trie.addOrUpdate(path, updatedValue);

        final result = trie.lookup(path);
        expect(wasAdded, isFalse);
        expect(result, isNotNull);
        expect(result!.value, equals(updatedValue));
      });

      test('Given an empty trie, '
          'when a new parameterized path is added with addOrUpdate, '
          'then the path is added', () {
        final pathDefinition = NormalizedPath('/users/:id');
        final lookupPath = NormalizedPath('/users/123');
        const value = 1;

        final wasAdded = trie.addOrUpdate(pathDefinition, value);

        final result = trie.lookup(lookupPath);
        expect(wasAdded, isTrue);
        expect(result, isNotNull);
        expect(result!.value, equals(value));
        expect(result.parameters, equals({#id: '123'}));
      });

      test('Given a trie with an existing parameterized path, '
          'when addOrUpdate is called for that path with a new value, '
          'then the value is updated', () {
        final pathDefinition = NormalizedPath('/users/:id');
        final lookupPath = NormalizedPath('/users/123');
        const initialValue = 1;
        const updatedValue = 2;
        trie.add(pathDefinition, initialValue);

        final wasAdded = trie.addOrUpdate(pathDefinition, updatedValue);

        final result = trie.lookup(lookupPath);
        expect(wasAdded, isFalse);
        expect(result, isNotNull);
        expect(result!.value, equals(updatedValue));
        expect(result.parameters, equals({#id: '123'}));
      });

      test('Given a trie with a path /a (with a value), '
          'when addOrUpdate is called for /a/b, '
          'then both are retrievable', () {
        final pathA = NormalizedPath('/a');
        final pathAB = NormalizedPath('/a/b');
        trie.addOrUpdate(pathA, 1);

        final wasAddedAB = trie.addOrUpdate(pathAB, 2);

        expect(wasAddedAB, isTrue);
        expect(trie.lookup(pathA)?.value, 1);
        expect(trie.lookup(pathAB)?.value, 2);
      });

      test(
        'Given a trie with a path /a/b/c (making /a/b an intermediate node), '
        'when addOrUpdate is called for /a/b to give it a value, '
        'then both are retrievable',
        () {
          final pathABC = NormalizedPath('/a/b/c');
          final pathAB = NormalizedPath('/a/b');
          trie.addOrUpdate(
            pathABC,
            1,
          ); // /a/b is created as an intermediate node

          final wasAddedAB = trie.addOrUpdate(pathAB, 2);

          expect(wasAddedAB, isTrue);
          expect(trie.lookup(pathAB)?.value, 2);
          expect(trie.lookup(pathABC)?.value, 1);
        },
      );
    });

    group('update', () {
      test('Given a trie with an existing path and value, '
          'when update is called with that path and a new value, '
          'then lookup returns the new value', () {
        final path = NormalizedPath('/posts');
        trie.add(path, 1);

        trie.update(path, 2);

        final result = trie.lookup(path);
        expect(result, isNotNull);
        expect(result!.value, equals(2));
      });

      test('Given a trie, '
          'when update is called for a path that does not exist, '
          'then an ArgumentError is thrown', () {
        final path = NormalizedPath('/nonexistent');

        expect(() => trie.update(path, 1), throwsArgumentError);
        expect(
          trie.lookup(path),
          isNull,
          reason: 'Path should not have been added.',
        );
      });

      test('Given a trie with /a/b (making /a intermediate and valueless), '
          'when update is called for /a, '
          'then an ArgumentError is thrown', () {
        trie.add(NormalizedPath('/a/b'), 2);
        final pathA = NormalizedPath('/a');

        expect(() => trie.update(pathA, 1), throwsArgumentError);
        expect(
          trie.lookup(pathA),
          isNull,
          reason: '/a should not have gained a value.',
        );
        expect(
          trie.lookup(NormalizedPath('/a/b'))?.value,
          2,
          reason: 'Child path should be unaffected.',
        );
      });

      test('Given a trie with an existing parameterized path and value, '
          'when update is called with that path and a new value, '
          'then lookup returns the new value', () {
        final pathDefinition = NormalizedPath('/posts/:id');
        trie.add(pathDefinition, 1);

        trie.update(pathDefinition, 2);

        final result = trie.lookup(NormalizedPath('/posts/abc'));
        expect(result, isNotNull);
        expect(result!.value, equals(2));
        expect(result.parameters, equals({#id: 'abc'}));
      });

      test('Given a trie, '
          'when update is called for a parameterized path that does not exist as a defined route, '
          'then an ArgumentError is thrown', () {
        final pathDefinition = NormalizedPath('/articles/:id');

        expect(() => trie.update(pathDefinition, 1), throwsArgumentError);
        expect(trie.lookup(NormalizedPath('/articles/any')), isNull);
      });

      test('Given a trie with an existing wildcard path /data/* and value, '
          'when update is called for /data/* with a new value, '
          'then lookup for a matching path returns the new value', () {
        final pathDefinition = NormalizedPath('/data/*');
        trie.add(pathDefinition, 1);

        trie.update(pathDefinition, 2);

        // Verify by looking up a path that would match the wildcard definition
        final result = trie.lookup(NormalizedPath('/data/something'));
        expect(result, isNotNull);
        expect(result!.value, equals(2));
        expect(
          result.parameters,
          isEmpty,
        ); // Wildcards don't produce parameters
        expect(result.matched.toString(), '/data/something');
        expect(result.remaining.segments, isEmpty);
      });

      test('Given a trie, '
          'when update is called for a wildcard path /data/* that does not exist as a defined route, '
          'then an ArgumentError is thrown', () {
        final pathDefinition = NormalizedPath('/data/*');
        expect(() => trie.update(pathDefinition, 1), throwsArgumentError);
        expect(trie.lookup(NormalizedPath('/data/anything')), isNull);
      });

      test('Given a trie with an existing tail path /files/** and value, '
          'when update is called for /files/** with a new value, '
          'then lookup for a matching path returns the new value', () {
        final pathDefinition = NormalizedPath('/files/**');
        trie.add(pathDefinition, 1);

        trie.update(pathDefinition, 2);

        // Verify by looking up a path that would match the tail definition
        final result = trie.lookup(NormalizedPath('/files/a/b.txt'));
        expect(result, isNotNull);
        expect(result!.value, equals(2));
        expect(result.parameters, isEmpty);
        expect(result.matched.toString(), '/files');
        expect(result.remaining.toString(), '/a/b.txt');
      });

      test('Given a trie, '
          'when update is called for a tail path /files/** that does not exist as a defined route, '
          'then an ArgumentError is thrown', () {
        final pathDefinition = NormalizedPath('/files/**');
        expect(() => trie.update(pathDefinition, 1), throwsArgumentError);
        expect(trie.lookup(NormalizedPath('/files/anything/else')), isNull);
      });
    });

    group('remove', () {
      test('Given a trie with an existing leaf path and value, '
          'when remove is called, '
          'then the value returned is removed', () {
        final path = NormalizedPath('/comments');
        trie.add(path, 1);

        final removedValue = trie.remove(path);

        expect(removedValue, equals(1));
        expect(trie.lookup(path), isNull);
      });

      test('Given a trie, '
          'when remove is called for a path that does not exist, '
          'then nothing is removed', () {
        final path = NormalizedPath('/comments/123');
        trie.add(NormalizedPath('/other'), 1); // Ensure trie is not empty

        final removedValue = trie.remove(path);

        expect(removedValue, isNull);
        expect(trie.lookup(path), isNull);
        expect(trie.lookup(NormalizedPath('/other'))?.value, 1);
      });

      test('Given a trie with /a/b (making /a intermediate and valueless), '
          'when remove is called for /a, '
          'then nothing is removed', () {
        final pathA = NormalizedPath('/a');
        final pathAB = NormalizedPath('/a/b');
        trie.add(pathAB, 2);

        final removedValue = trie.remove(pathA);

        expect(removedValue, isNull, reason: '/a had no value to remove.');
        expect(trie.lookup(pathA), isNull);
        expect(trie.lookup(pathAB)?.value, 2);
      });

      test(
        'Given a trie with /parent (value) and /parent/child (value), '
        'when remove is called for /parent, '
        'then /parent value is removed, but /parent/child is still accessible',
        () {
          final parentPath = NormalizedPath('/articles');
          final childPath = NormalizedPath('/articles/details');
          trie.add(parentPath, 1);
          trie.add(childPath, 2);

          final removedValue = trie.remove(parentPath);

          expect(removedValue, equals(1));
          expect(
            trie.lookup(parentPath),
            isNull,
            reason: 'Value of /articles should be removed.',
          );
          expect(
            trie.lookup(childPath)?.value,
            2,
            reason: 'Child /articles/details should still be accessible.',
          );
        },
      );

      test('Given a trie with a parameterized path and value, '
          'when remove is called, '
          'then it returns the removed value', () {
        final pathDefinition = NormalizedPath('/users/:id/settings');
        trie.add(pathDefinition, 1);
        trie.add(NormalizedPath('/users/data'), 2); // Sibling path

        final removedValue = trie.remove(pathDefinition);

        expect(removedValue, equals(1));
        expect(trie.lookup(NormalizedPath('/users/123/settings')), isNull);
        expect(trie.lookup(NormalizedPath('/users/any/settings')), isNull);
        expect(
          trie.lookup(NormalizedPath('/users/data'))?.value,
          2,
          reason: 'Sibling path should be unaffected.',
        );
      });

      test('Given a trie with root path / (value) and child /a (value), '
          'when remove is called for /, '
          'then / value is removed, but /a is still accessible', () {
        final rootPath = NormalizedPath('/');
        final childPath = NormalizedPath('/a');
        trie.add(rootPath, 1);
        trie.add(childPath, 2);

        final removedValue = trie.remove(rootPath);

        expect(removedValue, equals(1));
        expect(trie.lookup(rootPath), isNull);
        expect(trie.lookup(childPath)?.value, 2);
      });

      test('Given a trie with only root path / having a value, '
          'when remove is called for /, '
          'then / value is removed', () {
        final rootPath = NormalizedPath('/');
        trie.add(rootPath, 1);

        final removedValue = trie.remove(rootPath);

        expect(removedValue, equals(1));
        expect(trie.lookup(rootPath), isNull);
      });

      test('Given a trie with /a/b/c and /a/b/d, '
          'when /a/b/c is removed, '
          'then /a/b/d should still be accessible.', () {
        final pathABC = NormalizedPath('/a/b/c');
        final pathABD = NormalizedPath('/a/b/d');
        trie.add(pathABC, 1);
        trie.add(pathABD, 2);

        final removedValue = trie.remove(pathABC);

        expect(removedValue, equals(1));
        expect(trie.lookup(pathABC), isNull);
        expect(trie.lookup(pathABD)?.value, 2);
      });

      test(
        'Given a trie with an existing wildcard path /data/* and value, '
        'when remove is called for /data/*, '
        'then the value is removed and lookup for matching paths returns null',
        () {
          final pathDefinition = NormalizedPath('/data/*');
          trie.add(pathDefinition, 10);
          trie.add(NormalizedPath('/data/fixed'), 20); // Sibling literal

          final removedValue = trie.remove(pathDefinition);

          expect(removedValue, equals(10));
          expect(
            trie.lookup(NormalizedPath('/data/any')),
            isNull,
            reason: 'Wildcard path should be removed.',
          );
          expect(
            trie.lookup(NormalizedPath('/data/fixed'))?.value,
            20,
            reason: 'Sibling literal path should be unaffected.',
          );
        },
      );

      test('Given a trie, '
          'when remove is called for a wildcard path /data/* that does not exist as a defined route, '
          'then null is returned and no other paths are affected', () {
        final pathDefinition = NormalizedPath('/data/*');
        trie.add(
          NormalizedPath('/other/*'),
          1,
        ); // Add a different wildcard path

        final removedValue = trie.remove(pathDefinition);

        expect(removedValue, isNull);
        expect(trie.lookup(NormalizedPath('/other/something'))?.value, 1);
      });

      test(
        'Given a trie with an existing tail path /files/** and value, '
        'when remove is called for /files/**, '
        'then the value is removed and lookup for matching paths returns null',
        () {
          final pathDefinition = NormalizedPath('/files/**');
          trie.add(pathDefinition, 30);
          trie.add(
            NormalizedPath('/files/specific/file.txt'),
            40,
          ); // More specific child

          final removedValue = trie.remove(pathDefinition);

          expect(removedValue, equals(30));
          expect(
            trie.lookup(NormalizedPath('/files/a/b/c')),
            isNull,
            reason: 'Tail path should be removed.',
          );
          final specificLookup = trie.lookup(
            NormalizedPath('/files/specific/file.txt'),
          );
          expect(
            specificLookup?.value,
            40,
            reason: 'More specific path should remain',
          );
        },
      );

      test('Given a trie, '
          'when remove is called for a tail path /files/** that does not exist as a defined route, '
          'then null is returned and no other paths are affected', () {
        final pathDefinition = NormalizedPath('/files/**');
        trie.add(NormalizedPath('/archive/**'), 1); // Add a different tail path

        final removedValue = trie.remove(pathDefinition);
        expect(removedValue, isNull);
        expect(trie.lookup(NormalizedPath('/archive/some/file'))?.value, 1);
      });
    });
  });
}
