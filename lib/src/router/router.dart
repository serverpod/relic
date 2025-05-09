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
  final staticRoutes = HashMap<NormalizedPath, T>();

  /// Stores dynamic routes (with parameters) in a [PathTrie] for efficient
  /// matching and parameter extraction.
  final PathTrie<T> dynamicRoutes = PathTrie<T>();

  /// Adds a route definition to the router.
  ///
  /// The [path] string defines the route pattern. Segments starting with `:` (e.g.,
  /// `:id`) are treated as parameters. The associated [value] (e.g., a request
  /// handler) is stored for this route.
  ///
  /// Routes are classified as static or dynamic based on whether the [path]'s
  /// normalized segments contain a parameter (like `:id`). Static routes are stored
  /// in a HashMap for O(1) average lookup, while dynamic routes are stored in a
  /// [PathTrie].
  ///
  /// If a static route with the same normalized path already exists, an
  /// [ArgumentError] is thrown. If adding a dynamic route path that already
  /// exists, an [ArgumentError] is thrown by the underlying [PathTrie].
  void add(final String path, final T value) {
    final normalizedPath = NormalizedPath(path);

    if (normalizedPath.hasParameters) {
      dynamicRoutes.add(normalizedPath, value);
    } else {
      if (staticRoutes.containsKey(normalizedPath)) {
        throw ArgumentError(
          'Duplicate static route: '
              'A route for the normalized path "$normalizedPath" already exists '
              '(from original path "$path").',
          'path',
        );
      }
      staticRoutes[normalizedPath] = value;
    }
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

    final value = staticRoutes[normalizedPath];
    return value != null
        ? LookupResult(value, {}) // No parameters for static routes
        : dynamicRoutes.lookup(normalizedPath);
  }
}
