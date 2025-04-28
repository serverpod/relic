import 'package:relic/src/router/lru_cache.dart';
import 'package:test/test.dart';

void main() {
  test(
      'Given a negative capacity'
      'when cache is created '
      'then it fails', () {
    expect(() => LruCache<String, int>(-1), throwsArgumentError);
  });

  test(
      'Given a positive capacity, '
      'when cache is created '
      'then length is 0', () {
    const capacity = 5;
    final cache = LruCache<String, int>(capacity);
    expect(cache.length, equals(0));
  });

  group('Given a cache', () {
    late LruCache<String, int> cache;

    setUp(() {
      cache = LruCache<String, int>(100);
    });

    test(
        'when items are put '
        'then they can be retrieved', () {
      cache['a'] = 1;
      cache['b'] = 2;

      expect(cache['a'], equals(1));
      expect(cache['b'], equals(2));
      expect(cache.length, equals(2));
    });

    test(
        'when getting a non-existent key after putting an item '
        'then returns null', () {
      cache['a'] = 1;
      final value = cache['non_existent'];
      expect(value, isNull);
    });

    test(
        'when putting the same key with a new value '
        'then the value is updated', () {
      cache['a'] = 1;
      cache['a'] = 10;
      expect(cache['a'], equals(10));
      expect(cache.length, equals(1));
    });

    test(
        'when the same key is put multiple times consecutively '
        'then the last value is stored', () {
      cache['a'] = 1;
      cache['a'] = 10;
      cache['a'] = 100;

      expect(cache['a'], equals(100));
      expect(cache.length, equals(1));
    });
  });

  group('Given a full cache with capacity 3', () {
    late LruCache<String, int> cache;

    setUp(() {
      cache = LruCache<String, int>(3);
      cache['a'] = 1; // LRU
      cache['b'] = 2;
      cache['c'] = 3; // MRU
    });

    test(
      'when an existing item is accessed (get) '
      'then it becomes the most recently used and eviction order changes',
      () {
        final _ = cache['a']; // Access 'a', making it MRU
        cache['d'] = 4; // Add 'd', 'b' should be evicted

        expect(cache['b'], isNull);
        expect(cache['a'], equals(1));
        expect(cache['c'], equals(3));
        expect(cache['d'], equals(4));
        expect(cache.length, equals(3));
      },
    );

    test(
      'when an existing item is updated (put) '
      'then it becomes the most recently used and eviction order changes',
      () {
        cache['a'] = 10; // Update 'a', making it MRU
        cache['d'] = 4; // Add 'd', 'b' should be evicted

        expect(cache['b'], isNull);
        expect(cache['a'], equals(10));
        expect(cache['c'], equals(3));
        expect(cache['d'], equals(4));
        expect(cache.length, equals(3));
      },
    );
  });

  group('Given a full cache with capacity 2', () {
    late LruCache<String, int> cache;

    setUp(() {
      cache = LruCache<String, int>(2);
      cache['a'] = 1; // LRU
      cache['b'] = 2; // MRU
    });

    test(
        'when a new item is put '
        'then the least recently used item is evicted', () {
      cache['c'] = 3; // Add 'c', evict 'a'

      expect(cache['a'], isNull);
      expect(cache['b'], equals(2));
      expect(cache['c'], equals(3));
      expect(cache.length, equals(2));
    });
  });

  group('Given a cache with capacity 1', () {
    late LruCache<String, int> cache;

    setUp(() {
      cache = LruCache<String, int>(1);
    });

    test(
        'when multiple items are put '
        'then only the last item remains', () {
      cache['a'] = 1;
      cache['b'] = 2; // Evicts 'a'

      expect(cache['a'], isNull);
      expect(cache['b'], equals(2));
      expect(cache.length, equals(1));
    });

    test(
        'when an item is accessed and then a new item is put '
        'then the accessed item is evicted', () {
      cache['b'] = 2; // Start with 'b'
      final _ = cache['b']; // Access 'b' (doesn't change much with capacity 1)
      cache['c'] = 3; // Put 'c', evicts 'b'

      expect(cache['b'], isNull);
      expect(cache['c'], equals(3));
      expect(cache.length, equals(1));
    });
  });
}
