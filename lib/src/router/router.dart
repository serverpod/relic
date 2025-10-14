import 'lookup_result.dart';
import 'method.dart';
import 'normalized_path.dart';
import 'path_trie.dart';

/// A wrapper around a fixed-length list used for mapping between method and value
/// for each registered path.
extension type _RouterEntry<T extends Object>._(List<T?> _routeByVerb)
    implements Iterable<T?> {
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

  Set<Method> get allowed =>
      Method.values.where((final method) => find(method) != null).toSet();
}

extension<T extends Object> on _RouterEntry<T>? {
  _RouterEntry<T> get orNew => this ?? _RouterEntry<T>();
}

/// A URL router that maps path patterns to values of type [T].
///
/// Supports static paths (e.g., `/users/profile`) and paths with named parameters
/// (e.g., `/users/:id`). Normalizes paths before matching.
///
/// ## Basic Routing
///
/// ```dart
/// final router = Router<Handler>();
///
/// // Static routes
/// router.get('/', (ctx) {
///   return ctx.respond(Response.ok(
///     body: Body.fromString('Home'),
///   ));
/// });
///
/// // Route with parameters
/// router.get('/users/:id', (ctx) {
///   final id = ctx.pathParameters['id'];
///   return ctx.respond(Response.ok(
///     body: Body.fromString('User $id'),
///   ));
/// });
///
/// // Multiple parameters
/// router.get('/posts/:year/:month/:slug', (ctx) {
///   final year = ctx.pathParameters['year'];
///   final month = ctx.pathParameters['month'];
///   final slug = ctx.pathParameters['slug'];
///   return ctx.respond(Response.ok());
/// });
/// ```
///
/// ## HTTP Methods
///
/// ```dart
/// router.get('/users', (ctx) => /* list users */);
/// router.post('/users', (ctx) => /* create user */);
/// router.put('/users/:id', (ctx) => /* update user */);
/// router.patch('/users/:id', (ctx) => /* partial update */);
/// router.delete('/users/:id', (ctx) => /* delete user */);
/// ```
///
/// ## Sub-routers
///
/// ```dart
/// final apiRouter = Router<Handler>();
/// apiRouter.get('/users', (ctx) => /* users */);
/// apiRouter.get('/posts', (ctx) => /* posts */);
///
/// final mainRouter = Router<Handler>();
/// mainRouter.attach('/api', apiRouter);
/// // Results in: /api/users, /api/posts
/// ```
///
/// ## Using with Pipeline
///
/// ```dart
/// final handler = const Pipeline()
///     .addMiddleware(routeWith(router))
///     .addHandler(respondWith((_) => Response.notFound()));
/// ```
final class Router<T extends Object> {
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
    _allRoutes.addOrUpdateInPlace(
      normalizedPath,
      (final r) => (r.orNew)..add(method, normalizedPath, route),
    );
  }

  /// Adds a middleware function to the router.
  ///
  /// The [path] defines the route pattern. Segments starting with `:` (e.g.,
  /// `:id`) are treated as parameters. The [map] function transforms matched route
  /// values during lookup, without modifying the stored routes.
  void use(final String path, final T Function(T) map) {
    _allRoutes.use(
        NormalizedPath(path),
        (final r) => _RouterEntry._(List.of(
              r.map((final v) => v == null ? null : map(v)),
              growable: false,
            )));
  }

  /// Attaches a sub-router to this router at the specified [path].
  ///
  /// The [path] string defines the route prefix for the sub-router. All routes
  /// defined in the sub-router will be prefixed with this path when matched.
  void attach(final String path, final Router<T> subRouter) {
    _allRoutes.attach(NormalizedPath(path), subRouter._allRoutes);
  }

  /// Looks up a route matching the provided [path].
  ///
  /// The input [path] string is normalized before lookup. Static routes are
  /// checked first, followed by dynamic routes in the trie.
  ///
  /// Returns a [RouterMatch] containing the associated value and any extracted
  /// parameters if a match is found. Returns [PathMiss] if no matching route exists,
  /// or [MethodMiss] if a route exists for the path, but the method don't match.
  LookupResult<T> lookup(final Method method, final String path) {
    final normalizedPath = NormalizedPath(path); // Normalize upfront
    final entry = _allRoutes.lookup(normalizedPath);
    if (entry == null) return PathMiss(normalizedPath);

    final route = entry.value.find(method);
    if (route == null) return MethodMiss(entry.value.allowed);

    return RouterMatch(
      route,
      entry.parameters,
      entry.matched,
      entry.remaining,
    );
  }

  /// Returns true if the router has no routes.
  bool get isEmpty => _allRoutes.isEmpty;
}

extension RouteEx<T extends Object> on Router<T> {
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

  /// Adds a route definition for a set of HTTP methods.
  ///
  /// This is a convenience method that calls `add` for each method in the provided set
  /// [methods].
  void anyOf(final Set<Method> methods, final String path, final T value) {
    for (final method in methods) {
      add(method, path, value);
    }
  }

  /// Adds a route definition for all HTTP methods (GET, POST, PUT, etc.).
  void any(final String path, final T value) =>
      anyOf(Method.values.toSet(), path, value);

  /// Create and attach a subrouter for a path. If one already exists they are merged.
  Router<T> group(final String path) {
    final subRouter = Router<T>();
    attach(path, subRouter);
    return subRouter;
  }
}
