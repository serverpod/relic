import 'dart:collection';

/// A simple Least Recently Used (LRU) cache implementation.
///
/// Keeps a fixed number of items ([_maxSize]). When the cache is full and a new
/// item is added, the least recently used item is evicted. Accessing an item
/// (get or update) marks it as the most recently used.
final class LruCache<K, V> {
  final int _bufferSize;
  final int _maxSize;

  var _hotBuffer = <K, V>{};
  // ignore: prefer_collection_literals
  final _cache = LinkedHashMap<K, V>();

  /// Creates an LRU cache with the specified maximum size.
  ///
  /// Throws an [ArgumentError] if [_maxSize] is not positive.
  LruCache(this._maxSize, {final int? bufferSize})
      : _bufferSize = bufferSize ?? _maxSize ~/ 5 // default to 20%
  {
    if (_maxSize <= 0) {
      throw ArgumentError('Cache size must be positive');
    }
  }

  /// Retrieves the value associated with [key].
  ///
  /// Returns null if the key is not found. Accessing the key marks it as the most
  /// recently used item.
  V? operator [](final K key) {
    // Check hot buffer first (no reordering needed)
    final hotValue = _hotBuffer[key];
    if (hotValue != null) {
      return hotValue;
    }

    final value = _cache.remove(key);
    if (value != null) {
      // Promote to hot buffer without modifying cold buffer order
      _hotBuffer[key] = value;
    }
    return value;
  }

  /// Associates [value] with [key] in the cache.
  ///
  /// If the key already exists, its value is updated. Adding or updating a key
  /// marks it as the most recently used item. If adding the item exceeds the cache
  /// capacity, the least recently used item is evicted.
  void operator []=(final K key, final V value) {
    // Always put in hot buffer first
    _hotBuffer[key] = value;

    // If hot buffer gets too big, flush to cold
    if (_hotBuffer.length >= _bufferSize) {
      _trim();
    }
  }

  void _trim() {
    // Move all hot items as recent item in cache
    for (final entry in _hotBuffer.entries) {
      _cache.remove(entry.key); // if present (to mark as recent)
      _cache[entry.key] = entry.value;
    }

    // Create new hot buffer. GC can claim old one in one go
    _hotBuffer = {};

    // Evict oldest entries if we've exceeded max size
    var keysToRemove = _cache.length - _maxSize;
    while (keysToRemove-- > 0) {
      _cache.remove(_cache.keys.first);
    }
  }

  /// Returns the current number of items in the cache.
  int get length => _hotBuffer.length + _cache.length;
}
