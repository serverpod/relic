import 'cache.dart';

/// A no-op [Cache] implementation that never stores or retrieves values.
///
/// Useful for high-cardinality workloads where caching causes more overhead
/// than it saves (e.g., many unique dynamic paths like `/users/:id`).
///
/// Example:
/// ```dart
/// NormalizedPath.interned = NoCache();
/// ```
final class NoCache<K, V> implements Cache<K, V> {
  /// Creates a no-op cache.
  const NoCache();

  @override
  V? operator [](final K key) => null;

  @override
  void operator []=(final K key, final V value) {}

  @override
  int get length => 0;
}
