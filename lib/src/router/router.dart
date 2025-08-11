import 'dart:collection';

import 'lookup_result.dart';
import 'normalized_path.dart';
import 'path_trie.dart';

enum Method {
  get,
  head,
  post,
  put,
  delete,
  patch,
  options,
  trace,
  connect,
}

/// A wrapper around a fixed-length list used for mapping between method and value
/// for each registered path.
extension type _RouterEntry<T>._(List<T?> _routeByVerb) {
  _RouterEntry()
      : _routeByVerb =
            List<T?>.filled(Method.values.length, null, growable: false);

  @pragma('vm:prefer-inline')
  void add(
    final Method method,
    final NormalizedPath normalizedPath, // only used for error message
    final T route,
  ) {
    final idx = method.index;
    if (_routeByVerb[idx] != null) {
      throw ArgumentError('"$method" already registered for "$normalizedPath"');
    }
    _routeByVerb[idx] = route;
  }

  @pragma('vm:prefer-inline')
  T? find(final Method method) => _routeByVerb[method.index];
}

extension<T> on _RouterEntry<T>? {
  _RouterEntry<T> get orNew => this ?? _RouterEntry<T>();
}

/// A URL router that maps path patterns to values of type [T].
///
/// Supports static paths (e.g., `/users/profile`) and paths with named parameters
/// (e.g., `/users/:id`). Normalizes paths before matching.
final class Router<T> {
  /// Stores static routes (no parameters) for fast lookups using a HashMap.
  /// The key is the [NormalizedPath] representation of the route.
  ///
  /// This cache is build lazily on lookup.
  final _staticCache = HashMap<NormalizedPath, _RouterEntry<T>>();

  /// Stores all routes (with or without parameters) in a [PathTrie] for efficient
  /// matching and parameter extraction.
  final _allRoutes = PathTrie<_RouterEntry<T>>();

  /// Adds a route definition to the router.
  ///
  /// The [path] string defines the route pattern. Segments starting with `:` (e.g.,
  /// `:id`) are treated as parameters. The associated [value] (e.g., a request
  /// handler) is stored for this route.
  void add(final Method method, final String path, final T route) {
    final normalizedPath = NormalizedPath(path); // Normalize upfront
    final entry = _allRoutes.addOrUpdateInPlace(
      normalizedPath,
      (final r) => (r.orNew)..add(method, normalizedPath, route),
    );
    if (!normalizedPath.hasParameters) {
      // Prime cache on add (but not on attach)
      _staticCache[normalizedPath] = entry;
    }
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
  LookupResult<T>? lookup(final Method method, final String path) {
    final normalizedPath = NormalizedPath(path); // Normalize upfront

    // Try static cache first
    final value = _staticCache[normalizedPath]?.find(method);
    if (value != null) {
      return LookupResult(
        value,
        const {},
        normalizedPath,
        NormalizedPath.empty,
      );
    }

    // Fall back to trie
    final entry = _allRoutes.lookup(normalizedPath);
    if (entry == null) return null;

    final route = entry.value.find(method);
    if (route == null) return null;

    // Cache static routes for future lookups
    if (entry.parameters.isEmpty) {
      _staticCache[normalizedPath] = entry.value;
    }

    return LookupResult(
      route,
      entry.parameters,
      entry.matched,
      entry.remaining,
    );
  }

  /// Returns true if the router has no routes.
  bool get isEmpty => _allRoutes.isEmpty;
}

extension RouteEx<T> on Router<T> {
  /// Adds a route definition for the GET HTTP method.
  ///
  /// Equivalent to calling `add(Method.get, path, value)`.
  void get(final String path, final T value) => add(Method.get, path, value);

  /// Adds a route definition for the HEAD HTTP method.
  ///
  /// Equivalent to calling `add(Method.head, path, value)`.
  void head(final String path, final T value) => add(Method.head, path, value);

  /// Adds a route definition for the POST HTTP method.
  ///
  /// Equivalent to calling `add(Method.post, path, value)`.
  void post(final String path, final T value) => add(Method.post, path, value);

  /// Adds a route definition for the PUT HTTP method.
  ///
  /// Equivalent to calling `add(Method.put, path, value)`.
  void put(final String path, final T value) => add(Method.put, path, value);

  /// Adds a route definition for the DELETE HTTP method.
  ///
  /// Equivalent to calling `add(Method.delete, path, value)`.
  void delete(final String path, final T value) =>
      add(Method.delete, path, value);

  /// Adds a route definition for the PATCH HTTP method.
  ///
  /// Equivalent to calling `add(Method.patch, path, value)`.
  void patch(final String path, final T value) =>
      add(Method.patch, path, value);

  /// Adds a route definition for the OPTIONS HTTP method.
  ///
  /// Equivalent to calling `add(Method.options, path, value)`.
  void options(final String path, final T value) =>
      add(Method.options, path, value);

  /// Adds a route definition for the TRACE HTTP method.
  ///
  /// Equivalent to calling `add(Method.trace, path, value)`.
  void trace(final String path, final T value) =>
      add(Method.trace, path, value);

  /// Adds a route definition for the CONNECT HTTP method.
  ///
  /// Equivalent to calling `add(Method.connect, path, value)`.
  void connect(final String path, final T value) =>
      add(Method.connect, path, value);

  /// Adds a route definition for all HTTP methods (GET, POST, PUT, etc.).
  ///
  /// This is a convenience method that calls `add` for each method in the [Method] enum.
  void any(final String path, final T value) {
    for (final method in Method.values) {
      add(method, path, value);
    }
  }

  /// Create a subrouter for a path
  Router<T> group(final String path) {
    final subRouter = Router<T>();
    attach(path, subRouter);
    return subRouter;
  }
}
