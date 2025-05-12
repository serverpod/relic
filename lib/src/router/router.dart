import 'dart:collection';

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

/// A wrapper around a fix length list used for mapping between method and value
/// for each registered path.
final class _RouterEntry<T> {
  // One entry per method.
  final _routeByVerb = List<T?>.filled(8, null, growable: false);

  @pragma('vm:prefer-inline')
  void add(final Method method, final T route) {
    final idx = method.index;
    if (_routeByVerb[idx] != null) {
      throw ArgumentError('$method already registered');
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
      (final r) => (r.orNew)..add(method, route),
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
    if (value != null) return LookupResult(value, const {});

    // Fall back to trie
    final entry = _allRoutes.lookup(normalizedPath);
    if (entry == null) return null;

    final route = entry.value.find(method);
    if (route == null) return null;

    // Cache static routes for future lookups
    if (entry.parameters.isEmpty) {
      _staticCache[normalizedPath] = entry.value;
    }

    return LookupResult(route, entry.parameters);
  }
}

extension RouteEx<T> on Router<T> {
  /// Adds a route definition for the GET HTTP method.
  ///
  /// Equivalent to calling `add(Verb.get, path, value)`.
  void get(final String path, final T value) => add(Method.get, path, value);

  /// Adds a route definition for the HEAD HTTP method.
  ///
  /// Equivalent to calling `add(Verb.head, path, value)`.
  void head(final String path, final T value) => add(Method.head, path, value);

  /// Adds a route definition for the POST HTTP method.
  ///
  /// Equivalent to calling `add(Verb.post, path, value)`.
  void post(final String path, final T value) => add(Method.post, path, value);

  /// Adds a route definition for the PUT HTTP method.
  ///
  /// Equivalent to calling `add(Verb.put, path, value)`.
  void put(final String path, final T value) => add(Method.put, path, value);

  /// Adds a route definition for the DELETE HTTP method.
  ///
  /// Equivalent to calling `add(Verb.delete, path, value)`.
  void delete(final String path, final T value) =>
      add(Method.delete, path, value);

  /// Adds a route definition for the PATCH HTTP method.
  ///
  /// Equivalent to calling `add(Verb.patch, path, value)`.
  void patch(final String path, final T value) =>
      add(Method.patch, path, value);

  /// Adds a route definition for the OPTIONS HTTP method.
  ///
  /// Equivalent to calling `add(Verb.options, path, value)`.
  void options(final String path, final T value) =>
      add(Method.options, path, value);

  /// Adds a route definition for the TRACE HTTP method.
  ///
  /// Equivalent to calling `add(Verb.trace, path, value)`.
  void trace(final String path, final T value) =>
      add(Method.trace, path, value);

  /// Adds a route definition for the CONNECT HTTP method.
  ///
  /// Equivalent to calling `add(Verb.connect, path, value)`.
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
}
