/// Abstract cache interface.
///
/// Implementations can provide different caching strategies, such as
/// [LruCache] for bounded least-recently-used eviction, or [NoCache]
/// to disable caching entirely.
abstract interface class Cache<K, V> {
  /// Retrieves the value associated with [key], or `null` if not present.
  V? operator [](K key);

  /// Associates [value] with [key] in the cache.
  void operator []=(K key, V value);

  /// Returns the current number of items in the cache.
  int get length;
}
