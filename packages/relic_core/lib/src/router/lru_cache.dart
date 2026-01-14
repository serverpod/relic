import 'dart:collection';

/// A simple Least Recently Used (LRU) cache implementation.
///
/// Keeps a fixed number of items ([_maxSize]). When the cache is full and a new
/// item is added, the least recently used item is evicted. Accessing an item
/// (get or update) marks it as the most recently used.
final class LruCache<K, V> {
  final int _maxSize;

  // ignore: prefer_collection_literals
  final _cache = LinkedHashMap<K, V>();

  /// Creates an LRU cache with the specified maximum size.
  ///
  /// Throws an [ArgumentError] if [_maxSize] is not positive.
  LruCache(this._maxSize) {
    if (_maxSize <= 0) {
      throw ArgumentError('Cache size must be positive');
    }
  }

  /// Retrieves the value associated with [key].
  ///
  /// Returns null if the key is not found. Accessing the key marks it as the most
  /// recently used item.
  V? operator [](final K key) {
    final value = _cache.remove(key);
    if (value != null) {
      // Re-insert to move to the end (most recently used position)
      _cache[key] = value;
    }
    return value;
  }

  /// Associates [value] with [key] in the cache.
  ///
  /// If the key already exists, its value is updated. Adding or updating a key
  /// marks it as the most recently used item. If adding the item exceeds the cache
  /// capacity, the least recently used item is evicted.
  void operator []=(final K key, final V value) {
    // Remove existing entry if present
    _cache.remove(key);

    // Add new entry (will be at the end - most recently used)
    _cache[key] = value;
    _trim();
  }

  void _trim() {
    // Evict oldest entries if we've exceeded max size
    var keysToRemove = _cache.length - _maxSize;
    while (keysToRemove-- > 0) {
      _cache.remove(_cache.keys.first);
    }
  }

  /// Returns the current number of items in the cache.
  int get length => _cache.length;
}
