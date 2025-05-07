import 'lru_cache.dart';

/// Represents a URL path that has been normalized.
///
/// Normalization includes:
/// - Resolving `.` and `..` segments.
/// - Removing empty segments caused by multiple consecutive slashes.
/// - Ensuring the path starts with a `/`.
///
/// Instances are interned using an LRU cache for efficiency, meaning identical
/// normalized paths will often share the same object instance.
class NormalizedPath {
  static final _interned = LruCache<String, NormalizedPath>(10000);

  /// The individual segments of the normalized path.
  /// For example, the path `/a/b/c` would have segments `['a', 'b', 'c']`.
  final List<String> segments;

  /// Private constructor to create an instance with already normalized segments.
  NormalizedPath._(this.segments);

  /// Creates a [NormalizedPath] from a given [path] string.
  ///
  /// The provided [path] will be normalized by resolving `.` and `..` segments
  /// and removing empty segments. The resulting [NormalizedPath] instance may be
  /// retrieved from a cache if an identical normalized path has been created
  /// recently.
  factory NormalizedPath(final String path) {
    var result = _interned[path];
    if (result == null) {
      result = NormalizedPath._(_normalize(path));
      // intern for both normalized path and path
      result = _interned[result.path] ??= result;
      _interned[path] = result; // cache for original path as well
    }
    return result;
  }

  /// Normalizes the given [path] string into a list of segments.
  ///
  /// Handles `.` and `..` segments and removes empty ones.
  static List<String> _normalize(final String path) {
    final result = <String>[];

    for (final segment in path.split('/')) {
      if (segment == '..') {
        if (result.isNotEmpty) {
          result.removeLast();
        }
        // Note: '..' at root is ignored
      } else if (segment != '.' && segment.isNotEmpty) {
        result.add(segment);
      }
    }
    return result;
  }

  /// The string representation of the normalized path, always starting with `/`.
  ///
  /// For example, `NormalizedPath('a/b//c/./../d')` results in a path of `/a/b/d`.
  late final path = '/${segments.join('/')}';

  /// Returns the normalized path string.
  @override
  String toString() => path;

  /// The hash code for this normalized path, based on its segments.
  @override
  late final int hashCode = Object.hashAll(segments);

  /// Compares this [NormalizedPath] to another object for equality.
  ///
  /// Returns true if the other object is also a [NormalizedPath] and represents the
  /// exact same sequence of path segments.
  @override
  bool operator ==(final Object other) {
    if (identical(this, other)) return true;
    if (other is! NormalizedPath) return false;

    // Fast path: compare hash codes and segment counts first
    if (hashCode != other.hashCode) return false;
    final length = segments.length;
    if (length != other.segments.length) return false;

    // Compare segments only if needed
    for (int i = 0; i < length; i++) {
      if (segments[i] != other.segments[i]) return false;
    }
    return true;
  }
}
