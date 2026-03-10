import 'package:relic_core/relic_core.dart';
import 'package:test/test.dart';

void main() {
  group('Given a NoCache', () {
    late NoCache<String, int> cache;

    setUp(() {
      cache = const NoCache<String, int>();
    });

    test('when retrieving a key '
        'then it returns null', () {
      expect(cache['a'], isNull);
    });

    test('when storing a value '
        'then it cannot be retrieved', () {
      cache['a'] = 1;
      expect(cache['a'], isNull);
    });

    test('when checking length '
        'then it is always 0', () {
      cache['a'] = 1;
      cache['b'] = 2;
      expect(cache.length, equals(0));
    });
  });

  group('Given NormalizedPath with NoCache', () {
    late Cache<String, NormalizedPath> originalCache;

    setUp(() {
      originalCache = NormalizedPath.interned;
      NormalizedPath.interned = const NoCache();
    });

    tearDown(() {
      NormalizedPath.interned = originalCache;
    });

    test('when creating NormalizedPath '
        'then normalization still works correctly', () {
      final path = NormalizedPath('/a/b/c');
      expect(path.segments, equals(['a', 'b', 'c']));
      expect(path.toString(), equals('/a/b/c'));
    });

    test('when creating equivalent paths '
        'then they are equal but not identical', () {
      final path1 = NormalizedPath('/a/b');
      final path2 = NormalizedPath('/a/b');
      expect(path1, equals(path2));
      expect(identical(path1, path2), isFalse);
    });

    test('when normalizing complex paths '
        'then normalization is correct', () {
      final path = NormalizedPath('/a/./b/../c');
      expect(path.segments, equals(['a', 'c']));
      expect(path.toString(), equals('/a/c'));
    });
  });

  group('Given NormalizedPath with custom-sized LruCache', () {
    late Cache<String, NormalizedPath> originalCache;

    setUp(() {
      originalCache = NormalizedPath.interned;
      NormalizedPath.interned = LruCache<String, NormalizedPath>(2);
    });

    tearDown(() {
      NormalizedPath.interned = originalCache;
    });

    test('when cache capacity is exceeded '
        'then old entries are evicted', () {
      final path1 = NormalizedPath('/a');
      NormalizedPath('/b'); // fill cache
      final path3 = NormalizedPath('/c');

      // path1 should have been evicted from the small cache
      final path1Again = NormalizedPath('/a');
      expect(path1, equals(path1Again));
      // With a cache of size 2, after /a, /b, /c, /a is evicted
      // so creating /a again produces a new (non-identical) instance
      expect(identical(path1, path1Again), isFalse);

      // path3 and path2 should still be cached (or path3 and path1Again)
      expect(identical(path3, NormalizedPath('/c')), isTrue);
    });
  });
}
