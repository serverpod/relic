import 'package:mockito/mockito.dart';
import 'package:relic_core/relic_core.dart';
import 'package:test/test.dart';

void main() {
  group('Normalization Logic', () {
    test('Given a simple path, '
        'when normalized, '
        'then segments are correct', () {
      final path = NormalizedPath('a/b/c');
      expect(path.segments, equals(['a', 'b', 'c']));
      expect(path.toString(), equals('/a/b/c'));
    });

    test('Given path with leading slash, '
        'when normalized, '
        'then segments are correct', () {
      final path = NormalizedPath('/a/b/c');
      expect(path.segments, equals(['a', 'b', 'c']));
      expect(path.toString(), equals('/a/b/c'));
    });

    test('Given path with trailing slash, '
        'when normalized, '
        'then trailing slash is ignored', () {
      final path = NormalizedPath('a/b/c/');
      expect(path.segments, equals(['a', 'b', 'c']));
      expect(path.toString(), equals('/a/b/c'));
    });

    test('Given path with "." segments, '
        'when normalized, '
        'then "." segments are removed', () {
      final path = NormalizedPath('/a/./b/./c');
      expect(path.segments, equals(['a', 'b', 'c']));
      expect(path.toString(), equals('/a/b/c'));
    });

    test('Given path with ".." segments, '
        'when normalized, '
        'then ".." navigates up', () {
      final path = NormalizedPath('/a/b/../c');
      expect(path.segments, equals(['a', 'c']));
      expect(path.toString(), equals('/a/c'));
    });

    test('Given path with ".." segments at start, '
        'when normalized, '
        'then ".." is ignored', () {
      final path = NormalizedPath('../a/b');
      expect(path.segments, equals(['a', 'b']));
      expect(path.toString(), equals('/a/b'));
    });

    test('Given path with excessive ".." segments, '
        'when normalized, '
        'then it stops at root', () {
      final path = NormalizedPath('/a/../../b');
      expect(path.segments, equals(['b']));
      expect(path.toString(), equals('/b'));
    });

    test('Given path with multiple consecutive slashes, '
        'when normalized, '
        'then they are treated as one', () {
      final path = NormalizedPath('a///b//c');
      expect(path.segments, equals(['a', 'b', 'c']));
      expect(path.toString(), equals('/a/b/c'));
    });

    test('Given an empty path string, '
        'when normalized, '
        'then results in root', () {
      final path = NormalizedPath('');
      expect(path.segments, isEmpty);
      expect(path.toString(), equals('/'));
    });

    test('Given a path string with only slashes, '
        'when normalized, '
        'then results in root', () {
      final path = NormalizedPath('///');
      expect(path.segments, isEmpty);
      expect(path.path, equals('/'));
    });

    test('Given a path string with only dots and slashes, '
        'when normalized, '
        'then results in root', () {
      final path = NormalizedPath('././');
      expect(path.segments, isEmpty);
      expect(path.toString(), equals('/'));
    });
  });

  group('Interning', () {
    test('Given identical path strings, '
        'when creating NormalizedPath, '
        'then returns identical instances', () {
      final path1 = NormalizedPath('/a/b');
      final path2 = NormalizedPath('/a/b');
      expect(identical(path1, path2), isTrue);
    });

    test('Given logically equivalent path strings, '
        'when creating NormalizedPath, '
        'then returns identical instances', () {
      final path1 = NormalizedPath('a/b'); // No leading slash
      final path2 = NormalizedPath('/a/b/'); // Leading and trailing slash
      final path3 = NormalizedPath('a/./b'); // Contains '.' segment
      expect(identical(path1, path2), isTrue);
      expect(identical(path1, path3), isTrue);
    });

    test('Given different logical paths, '
        'when creating NormalizedPath, '
        'then returns different instances', () {
      final path1 = NormalizedPath('/a/b');
      final path2 = NormalizedPath('/a/c');
      final path3 = NormalizedPath('/a');
      expect(identical(path1, path2), isFalse);
      expect(identical(path1, path3), isFalse);
    });

    // Note: The interning cache (LruCache) has a size limit.
    // Testing eviction is complex and depends on the exact cache size and usage order.
    // We focus on the core interning guarantee for reasonably accessed paths.
  });

  group('Equality and HashCode', () {
    test('Given identical path strings, '
        'when creating NormalizedPath, '
        'then instances are equal and hash codes match', () {
      final path1 = NormalizedPath('/a/b');
      final path2 = NormalizedPath('/a/b');
      expect(path1, equals(path2));
      expect(path1.hashCode, equals(path2.hashCode));
    });

    test('Given logically equivalent path strings, '
        'when creating NormalizedPath, '
        'then instances are equal and hash codes match', () {
      final path1 = NormalizedPath('a/b');
      final path2 = NormalizedPath('/a/b/');
      final path3 = NormalizedPath('a/./b/../b'); // More complex normalization
      expect(path1, equals(path2));
      expect(path1.hashCode, equals(path2.hashCode));
      expect(path1, equals(path3));
      expect(path1.hashCode, equals(path3.hashCode));
    });

    test('Given different logical paths, '
        'when creating NormalizedPath, '
        'then instances are not equal', () {
      final path1 = NormalizedPath('/a/b');
      final path2 = NormalizedPath('/a/c');
      final path3 = NormalizedPath('/a');
      final path4 = NormalizedPath('/a/b/c');
      expect(path1, isNot(equals(path2)));
      expect(path1, isNot(equals(path3)));
      expect(path1, isNot(equals(path4)));
    });

    test('Given different types, '
        'when comparing, '
        'then == returns false', () {
      final path = NormalizedPath('/a/b');
      const other = '/a/b';
      // ignore: unrelated_type_equality_checks
      expect(path == other, isFalse); // use == to avoid matcher smartness
    });

    group('Given different instances, but same hashCode (collision), ', () {
      late final real = NormalizedPath('/a/b');
      test('when segment count differs, '
          'then == returns false via length check', () {
        // Force same hashCode but only one segment
        final fake = _FakeNormalizedPath(NormalizedPath('/a'), real.hashCode);

        // hashCode check passes, then length check kicks in and returns false
        expect(real == fake, isFalse); // use == to avoid matcher smartness
      });

      test('when segments differs, '
          'then == returns false via length check', () {
        // Force same hashCode but only one segment
        final fake = _FakeNormalizedPath(NormalizedPath('/a/x'), real.hashCode);

        // hashCode and length check passes, then segment check kicks in and returns false
        expect(real == fake, isFalse); // use == to avoid matcher smartness
      });

      test('when segment are equal, '
          'then == returns true', () {
        // Force same hashCode but only one segment
        final fake = _FakeNormalizedPath(NormalizedPath('/a/b'), real.hashCode);

        // These are equal despite not being same instance
        expect(real == fake, isTrue); // use == to avoid matcher smartness
      });
    });
  });

  group('toString()', () {
    test('Given various path initializations, '
        'when calling toString(), '
        'then returns canonical path starting with /', () {
      expect(NormalizedPath('a/b').toString(), equals('/a/b'));
      expect(NormalizedPath('/a/b/').toString(), equals('/a/b'));
      expect(NormalizedPath('').toString(), equals('/'));
      expect(NormalizedPath('/').toString(), equals('/'));
      expect(NormalizedPath('a/../b').toString(), equals('/b'));
    });
  });
}

// A test‐only subclass to override hashCode to simulate collisions
class _FakeNormalizedPath extends Fake implements NormalizedPath {
  final NormalizedPath original;
  @override
  final int hashCode; // ignore: hash_and_equals

  _FakeNormalizedPath(this.original, this.hashCode);

  @override
  List<String> get segments => original.segments;
}
