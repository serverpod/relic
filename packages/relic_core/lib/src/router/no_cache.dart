import 'cache.dart';

/// A no-op [Cache] that never stores or retrieves values, for opting out of
/// caching in high-cardinality workloads where it costs more than it saves.
final class NoCache<K, V> implements Cache<K, V> {
  /// Creates a no-op cache.
  const NoCache();

  @override
  V? operator [](K key) => null;

  @override
  void operator []=(K key, V value) {}

  @override
  int get length => 0;
}
