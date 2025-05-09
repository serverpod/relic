import 'package:relic/src/router/normalized_path.dart';
import 'package:relic/src/router/path_trie.dart';
import 'package:test/test.dart';

void main() {
  group('PathTrie CRUD operations', () {
    late PathTrie<int> trie;

    setUp(() {
      trie = PathTrie<int>();
    });

    group('addOrUpdate', () {
      test(
          'Given an empty trie, '
          'when a new path is added with addOrUpdate, '
          'then the path is added, lookup returns the value, and addOrUpdate returns false (added)',
          () {
        // GIVEN: an empty trie and a path
        final path = NormalizedPath('/users');
        const value = 1;

        // WHEN: addOrUpdate is called
        final wasUpdated = trie.addOrUpdate(path, value);

        // THEN: the path is added and correct results are returned
        final result = trie.lookup(path);
        expect(wasUpdated, isFalse,
            reason: 'Should return false as it was a new entry.');
        expect(result, isNotNull);
        expect(result!.value, equals(value));
        expect(result.parameters, isEmpty);
      });

      test(
          'Given a trie with an existing path, '
          'when addOrUpdate is called for the same path with a new value, '
          'then the value is updated, lookup returns the new value, and addOrUpdate returns true (updated)',
          () {
        // GIVEN: a trie with an existing path
        final path = NormalizedPath('/users');
        const initialValue = 1;
        const updatedValue = 2;
        trie.add(path, initialValue); // Pre-populate using standard add

        // WHEN: addOrUpdate is called for the existing path
        final wasUpdated = trie.addOrUpdate(path, updatedValue);

        // THEN: the value is updated and correct results are returned
        final result = trie.lookup(path);
        expect(wasUpdated, isTrue,
            reason: 'Should return true as it updated an existing entry.');
        expect(result, isNotNull);
        expect(result!.value, equals(updatedValue));
      });

      test(
          'Given an empty trie, '
          'when a new parameterized path is added with addOrUpdate, '
          'then the path is added, lookup returns the value with parameters, and addOrUpdate returns false',
          () {
        // GIVEN: an empty trie and a parameterized path
        final pathDefinition = NormalizedPath('/users/:id');
        final lookupPath = NormalizedPath('/users/123');
        const value = 1;

        // WHEN: addOrUpdate is called
        final wasUpdated = trie.addOrUpdate(pathDefinition, value);

        // THEN: the path is added and correct results are returned
        final result = trie.lookup(lookupPath);
        expect(wasUpdated, isFalse);
        expect(result, isNotNull);
        expect(result!.value, equals(value));
        expect(result.parameters, equals({#id: '123'}));
      });

      test(
          'Given a trie with an existing parameterized path, '
          'when addOrUpdate is called for that path with a new value, '
          'then the value is updated, lookup returns new value with parameters, and addOrUpdate returns true',
          () {
        // GIVEN: a trie with an existing parameterized path
        final pathDefinition = NormalizedPath('/users/:id');
        final lookupPath = NormalizedPath('/users/123');
        const initialValue = 1;
        const updatedValue = 2;
        trie.add(pathDefinition, initialValue);

        // WHEN: addOrUpdate is called
        final wasUpdated = trie.addOrUpdate(pathDefinition, updatedValue);

        // THEN: the value is updated and correct results are returned
        final result = trie.lookup(lookupPath);
        expect(wasUpdated, isTrue);
        expect(result, isNotNull);
        expect(result!.value, equals(updatedValue));
        expect(result.parameters, equals({#id: '123'}));
      });

      test(
          'Given a trie with a path /a (with a value), '
          'when addOrUpdate is called for /a/b, '
          'then /a/b is added with its value, /a retains its value, and both are retrievable',
          () {
        // GIVEN: a trie with /a having a value
        final pathA = NormalizedPath('/a');
        final pathAB = NormalizedPath('/a/b');
        trie.addOrUpdate(pathA, 1);

        // WHEN: addOrUpdate is called for /a/b
        final wasUpdatedAB = trie.addOrUpdate(pathAB, 2);

        // THEN: /a/b is added, /a remains, both values are correct
        expect(wasUpdatedAB, isFalse);
        expect(trie.lookup(pathA)?.value, 1);
        expect(trie.lookup(pathAB)?.value, 2);
      });

      test(
          'Given a trie with a path /a/b/c (making /a/b an intermediate node), '
          'when addOrUpdate is called for /a/b to give it a value, '
          'then /a/b gets the value, /a/b/c remains accessible, and addOrUpdate for /a/b returns false (added value to existing node)',
          () {
        // GIVEN: /a/b/c exists, /a/b is intermediate without its own value
        final pathABC = NormalizedPath('/a/b/c');
        final pathAB = NormalizedPath('/a/b');
        trie.addOrUpdate(pathABC, 1); // /a/b is created as an intermediate node

        // WHEN: addOrUpdate is called for /a/b
        final wasUpdatedAB = trie.addOrUpdate(pathAB, 2);

        // THEN: /a/b now has a value, /a/b/c is still there
        expect(wasUpdatedAB, isFalse,
            reason:
                "/a/b didn't have a value, so it's an addition of value, not an update of existing value.");
        expect(trie.lookup(pathAB)?.value, 2);
        expect(trie.lookup(pathABC)?.value, 1);
      });
    });

    group('update', () {
      test(
          'Given a trie with an existing path and value, '
          'when update is called with that path and a new value, '
          'then lookup returns the new value', () {
        // GIVEN: a path with a value
        final path = NormalizedPath('/posts');
        trie.add(path, 1);

        // WHEN: update is called
        trie.update(path, 2);

        // THEN: the value is updated
        final result = trie.lookup(path);
        expect(result, isNotNull);
        expect(result!.value, equals(2));
      });

      test(
          'Given a trie, '
          'when update is called for a path that does not exist, '
          'then an ArgumentError is thrown', () {
        // GIVEN: a path that doesn't exist
        final path = NormalizedPath('/nonexistent');

        // WHEN/THEN: update is called and throws
        expect(() => trie.update(path, 1), throwsArgumentError);
        expect(trie.lookup(path), isNull,
            reason: 'Path should not have been added.');
      });

      test(
          'Given a trie with /a/b (making /a intermediate and valueless), '
          'when update is called for /a, '
          'then an ArgumentError is thrown', () {
        // GIVEN: /a is an intermediate node without a value
        trie.add(NormalizedPath('/a/b'), 2);
        final pathA = NormalizedPath('/a');

        // WHEN/THEN: update is called for /a and throws
        expect(() => trie.update(pathA, 1), throwsArgumentError,
            reason:
                "Cannot update a node that doesn't have an explicit value.");
        expect(trie.lookup(pathA), isNull,
            reason: '/a should not have gained a value.');
        expect(trie.lookup(NormalizedPath('/a/b'))?.value, 2,
            reason: 'Child path should be unaffected.');
      });

      test(
          'Given a trie with an existing parameterized path and value, '
          'when update is called with that path and a new value, '
          'then lookup returns the new value', () {
        // GIVEN: a parameterized path with a value
        final pathDefinition = NormalizedPath('/posts/:id');
        trie.add(pathDefinition, 1);

        // WHEN: update is called
        trie.update(pathDefinition, 2);

        // THEN: the value is updated for the parameterized path
        final result = trie.lookup(NormalizedPath('/posts/abc'));
        expect(result, isNotNull);
        expect(result!.value, equals(2));
        expect(result.parameters, equals({#id: 'abc'}));
      });

      test(
          'Given a trie, '
          'when update is called for a parameterized path that does not exist as a defined route, '
          'then an ArgumentError is thrown', () {
        // GIVEN: a parameterized path that hasn't been added
        final pathDefinition = NormalizedPath('/articles/:id');

        // WHEN/THEN: update is called and throws
        expect(() => trie.update(pathDefinition, 1), throwsArgumentError);
        expect(trie.lookup(NormalizedPath('/articles/any')), isNull);
      });
    });

    group('remove', () {
      test(
          'Given a trie with an existing leaf path and value, '
          'when remove is called, '
          'then it returns the removed value and lookup for that path returns null',
          () {
        // GIVEN: a path with a value
        final path = NormalizedPath('/comments');
        trie.add(path, 1);

        // WHEN: remove is called
        final removedValue = trie.remove(path);

        // THEN: value is removed and correct value returned
        expect(removedValue, equals(1));
        expect(trie.lookup(path), isNull);
      });

      test(
          'Given a trie, '
          'when remove is called for a path that does not exist, '
          'then it returns null and the trie is unchanged', () {
        // GIVEN: a path that doesn't exist
        final path = NormalizedPath('/comments/123');
        trie.add(NormalizedPath('/other'), 1); // Ensure trie is not empty

        // WHEN: remove is called for non-existent path
        final removedValue = trie.remove(path);

        // THEN: null is returned, other paths unaffected
        expect(removedValue, isNull);
        expect(trie.lookup(path), isNull);
        expect(trie.lookup(NormalizedPath('/other'))?.value, 1);
      });

      test(
          'Given a trie with /a/b (making /a intermediate and valueless), '
          'when remove is called for /a, '
          'then it returns null and /a/b is still accessible', () {
        // GIVEN: /a is intermediate and valueless, /a/b has a value
        final pathA = NormalizedPath('/a');
        final pathAB = NormalizedPath('/a/b');
        trie.add(pathAB, 2);

        // WHEN: remove is called for /a
        final removedValue = trie.remove(pathA);

        // THEN: null is returned, /a/b remains
        expect(removedValue, isNull, reason: '/a had no value to remove.');
        expect(trie.lookup(pathA), isNull);
        expect(trie.lookup(pathAB)?.value, 2);
      });

      test(
          'Given a trie with /parent (value) and /parent/child (value), '
          'when remove is called for /parent, '
          'then /parent value is removed (returns value), lookup is null, but /parent/child is still accessible',
          () {
        // GIVEN: parent and child both have values
        final parentPath = NormalizedPath('/articles');
        final childPath = NormalizedPath('/articles/details');
        trie.add(parentPath, 1);
        trie.add(childPath, 2);

        // WHEN: remove is called for the parent path
        final removedValue = trie.remove(parentPath);

        // THEN: parent's value is removed, child remains
        expect(removedValue, equals(1));
        expect(trie.lookup(parentPath), isNull,
            reason: 'Value of /articles should be removed.');
        expect(trie.lookup(childPath)?.value, 2,
            reason: 'Child /articles/details should still be accessible.');
      });

      test(
          'Given a trie with a parameterized path and value, '
          'when remove is called, '
          'then it returns the removed value and lookup for that parameterized path returns null',
          () {
        // GIVEN: a parameterized path with a value
        final pathDefinition = NormalizedPath('/users/:id/settings');
        trie.add(pathDefinition, 1);
        trie.add(NormalizedPath('/users/data'), 2); // Sibling path

        // WHEN: remove is called for the parameterized path definition
        final removedValue = trie.remove(pathDefinition);

        // THEN: value is removed, path no longer matches
        expect(removedValue, equals(1));
        expect(trie.lookup(NormalizedPath('/users/123/settings')), isNull);
        expect(trie.lookup(NormalizedPath('/users/any/settings')), isNull);
        expect(trie.lookup(NormalizedPath('/users/data'))?.value, 2,
            reason: 'Sibling path should be unaffected.');
      });

      test(
          'Given a trie with root path / (value) and child /a (value), '
          'when remove is called for /, '
          'then / value is removed (returns value), but /a is still accessible',
          () {
        // GIVEN: root and child have values
        final rootPath = NormalizedPath('/');
        final childPath = NormalizedPath('/a');
        trie.add(rootPath, 1);
        trie.add(childPath, 2);

        // WHEN: remove is called for the root path
        final removedValue = trie.remove(rootPath);

        // THEN: root value is removed, child remains
        expect(removedValue, equals(1));
        expect(trie.lookup(rootPath), isNull);
        expect(trie.lookup(childPath)?.value, 2);
      });

      test(
          'Given a trie with only root path / having a value, '
          'when remove is called for /, '
          'then / value is removed (returns value) and lookup is null', () {
        // GIVEN: only root has a value
        final rootPath = NormalizedPath('/');
        trie.add(rootPath, 1);

        // WHEN: remove is called for the root path
        final removedValue = trie.remove(rootPath);

        // THEN: root value is removed
        expect(removedValue, equals(1));
        expect(trie.lookup(rootPath), isNull);
      });

      test(
          'Given a trie with /a/b/c and /a/b/d, '
          'when /a/b/c is removed, '
          'then /a/b/d should still be accessible and /a/b (intermediate node) should not be affected.',
          () {
        // GIVEN: two sibling paths sharing a common prefix
        final pathABC = NormalizedPath('/a/b/c');
        final pathABD = NormalizedPath('/a/b/d');
        trie.add(pathABC, 1);
        trie.add(pathABD, 2);
        // Optionally give /a/b a value to test its persistence
        trie.addOrUpdate(NormalizedPath('/a/b'), 3);

        // WHEN: one of the sibling paths is removed
        final removedValue = trie.remove(pathABC);

        // THEN: the removed path is gone, the other remains, intermediate nodes unchanged
        expect(removedValue, equals(1));
        expect(trie.lookup(pathABC), isNull);
        expect(trie.lookup(pathABD)?.value, 2);
        expect(trie.lookup(NormalizedPath('/a/b'))?.value, 3,
            reason:
                'Intermediate node /a/b should retain its value if it had one.');
      });
    });
  });
}
