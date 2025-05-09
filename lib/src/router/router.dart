import 'dart:collection';

import 'normalized_path.dart';
import 'path_trie.dart';

/// A URL router that maps path patterns to values of type [T].
///
/// Supports static paths (e.g., `/users/profile`) and paths with named parameters
/// (e.g., `/users/:id`). Normalizes paths before matching.
final class Router<T> {
  /// Stores static routes (no parameters) for fast lookups using a HashMap.
  /// The key is the [NormalizedPath] representation of the route.
  ///
  /// This cache is build lazily on lookup.
  final _staticCache = HashMap<NormalizedPath, T>();

  /// Stores all routes (with or without parameters) in a [PathTrie] for efficient
  /// matching and parameter extraction.
  final PathTrie<T> _allRoutes = PathTrie<T>();

  /// Adds a route definition to the router.
  ///
  /// The [path] string defines the route pattern. Segments starting with `:` (e.g.,
  /// `:id`) are treated as parameters. The associated [value] (e.g., a request
  /// handler) is stored for this route.
  void add(final String path, final T value) {
    final normalizedPath = NormalizedPath(path);
    _allRoutes.add(normalizedPath, value);
  }

  /// Attaches a sub-router to this router at the specified [path].
  ///
  /// The [path] string defines the route prefix for the sub-router. All routes
  /// defined in the sub-router will be prefixed with this path when matched.
  void attach(final String path, final Router<T> subRouter) {
    _allRoutes.attach(NormalizedPath(path), subRouter._allRoutes);
    subRouter._staticCache.clear();
  }

  /// Looks up a route matching the provided [path].
  ///
  /// The input [path] string is normalized before lookup. Static routes are
  /// checked first, followed by dynamic routes in the trie.
  ///
  /// Returns a [LookupResult] containing the associated value and any extracted
  /// parameters if a match is found. Returns `null` if no matching route exists.
  LookupResult<T>? lookup(final String path) {
    final normalizedPath = NormalizedPath(path); // Normalize upfront

    // Try cache first
    final value = _staticCache[normalizedPath];
    if (value != null) return LookupResult(value, const {}, false);

    // Fall back to trie
    final result = _allRoutes.lookup(normalizedPath);

    // Cache static routes for future lookups
    if (result != null && !result.isDynamic) {
      _staticCache[normalizedPath] = result.value;
    }

    return result;
  }
}
