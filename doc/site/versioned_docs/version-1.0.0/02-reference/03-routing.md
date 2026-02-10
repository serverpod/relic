---
sidebar_position: 3
---

# Routing

_Routing_ maps each incoming request to a handler based on its path (URI) and HTTP method.

Each route maps a request to a single handler.

Route definitions are added via `RelicRouter.add(...)` (or convenience methods on `RelicRouter`/`RelicApp`):

```dart
router.add(Method.get, '/my/path', myHandler);

// Or, with a convenience method:
router.get('/my/path', myHandler);
```

Where:

- `router` is an instance of `RelicRouter` or `RelicApp` (which implements `RelicRouter`).
- `Method` is the `Method` enum (e.g. `Method.get`, `Method.post`).
- `/my/path` is a path on the server.
- `myHandler` is a `Handler` that executes when the route is matched.

## The `add` method and its shortcuts

At the core of routing is the `add` method:

```dart
router.add(Method.get, '/', handler);
```

The convenience methods `.get()`, `.post()`, `.anyOf()`, and `.any()` call `add()` for you:

- `.get(path, handler)` → `.add(Method.get, path, handler)`
- `.post(path, handler)` → `.add(Method.post, path, handler)`
- `.anyOf({Method.get, Method.post}, path, handler)` → calls `.add()` for each method in the set.
- `.any(path, handler)` → calls `.anyOf()` with all HTTP methods.

## Breaking down the routes

The following examples break down each route from the complete example above.

### Convenience methods

These are convenience methods for the core `.add()` method:

**Respond with `Hello World!` on the homepage:**

GITHUB_CODE_BLOCK lang="dart" title="GET /" file="../_example/routing/basic_routing.dart" doctag="routing-get-root"

**Respond to a POST request on the root route:**

GITHUB_CODE_BLOCK lang="dart" title="POST /" file="../_example/routing/basic_routing.dart" doctag="routing-post-root"

**Respond to a PUT request to the `/user` route:**

GITHUB_CODE_BLOCK lang="dart" title="PUT /user" file="../_example/routing/basic_routing.dart" doctag="routing-put-user"

**Respond to a DELETE request to the `/user` route:**

GITHUB_CODE_BLOCK lang="dart" title="DELETE /user" file="../_example/routing/basic_routing.dart" doctag="routing-delete-user"

### Using the `add` method

This is what the convenience methods call internally:

**Respond to a PATCH request using the core `.add()` method:**

GITHUB_CODE_BLOCK lang="dart" title="PATCH /api" file="../_example/routing/basic_routing.dart" doctag="routing-patch-api"

### Using `anyOf` for multiple methods

Handle multiple HTTP methods with the same handler:

**Handle both GET and POST requests to `/admin`:**

GITHUB_CODE_BLOCK lang="dart" title="GET|POST /admin" file="../_example/routing/basic_routing.dart" doctag="routing-anyof-admin"

## Path parameters, wildcards, and tail segments

Relic's router supports three types of variable path segments:

- **Path parameters (`:id`)** capture named segments and are available via `request.pathParameters.raw`.
- **Wildcards (`*`)** match any single path segment but do not capture a value.
- **Tail segments (`/**`)** capture the rest of the path and expose it through `request.remainingPath`.

### Path parameters (`:id`)

Use a colon-prefixed name to capture a segment. Access the value with the `Symbol`-based key that matches the parameter name.

```dart
final app = RelicApp()
  ..get('/users/:id', (final Request request) {
    final userId = request.pathParameters.raw[#id];
    return Response.ok(
      body: Body.fromString('User $userId'),
    );
  });
```

#### Typed path parameters

Raw path parameters are always strings, which means you need to parse them manually. Relic provides typed parameter accessors that handle parsing automatically and give you compile-time type safety.

Define a parameter accessor once, then use it to extract typed values:

GITHUB_CODE_BLOCK lang="dart" file="../_example/routing/dynamic_segments.dart" doctag="routing-typed-path-params" title="Typed path parameters"

You can also use the nullable variant by calling the accessor directly:

GITHUB_CODE_BLOCK lang="dart" file="../_example/routing/dynamic_segments.dart" doctag="routing-typed-path-params-nullable" title="Nullable typed path parameter"

Relic provides these built-in typed parameter accessors:

| Accessor | Type | Description |
| -------- | ---- | ----------- |
| `IntPathParam` | `int` | Integer values (IDs, counts) |
| `DoublePathParam` | `double` | Decimal values (coordinates, measurements) |
| `NumPathParam` | `num` | Any numeric value |
| `PathParam<T>` | Custom | Create your own with a custom parser |

For custom types, use `PathParam<T>` with your own parsing function:

GITHUB_CODE_BLOCK lang="dart" file="../_example/routing/dynamic_segments.dart" doctag="routing-custom-path-param-inline" title="Custom type path parameters"

To create a reusable accessor like the built-in ones, extend `PathParam<T>` with a fixed decoder. The decoder must be a static function with signature `T Function(String)`:

GITHUB_CODE_BLOCK lang="dart" file="../_example/routing/dynamic_segments.dart" doctag="routing-custom-path-param" title="Custom PathParam specialization"

### Wildcards (`*`)

Use `*` to match any single segment without naming it. This is useful when the value does not matter, such as matching `/files/<anything>/download`.

GITHUB_CODE_BLOCK lang="dart" file="../_example/routing/dynamic_segments.dart" doctag="routing-wildcard-download" title="Wildcard path segment"

### Tail segments (`/**`)

Use `/**` at the end of a pattern to match the entire remaining path. The unmatched portion is available via `request.remainingPath`.

GITHUB_CODE_BLOCK lang="dart" file="../_example/routing/dynamic_segments.dart" doctag="routing-tail-segment" title="Tail segment"

Tail segments are required when serving directories so that the handler knows which file the client requested. A route like `/static` without `/**` would not expose the requested child path.

## Route matching and priority

When multiple routes could potentially match a request, Relic uses these rules:

1. **Literal segments take priority over dynamic segments** - A route with
   `/users/admin` is tried before `/users/:id` when matching `/users/admin`.

2. **Backtracking ensures the best match** - If a literal path leads to a dead
   end (no matching route), the router backtracks and tries dynamic
   alternatives.

This means you can freely combine:

- Specific routes (`/files/special/report`) with catch-all routes
  (`/files/**`)
- Literal and parameterized segments (`/api/v1/users` and
  `/api/:version/items`)

Route registration order does not affect matching, which makes it easy to
compose routers from separate modules without worrying about ordering.

The router uses a trie data structure to provide efficient matching. Typical
lookups run in _O(segments)_ time regardless of how many routes are registered.
Since each trie node is visited at most once during lookup, the worst case is
still bounded by the total number of paths registered. Hence it is never worse
than a linear scan.

### How backtracking works

Consider these routes:

```dart
router.get('/:entity/:id', entityHandler);      // Route 1
router.get('/users/:id/profile', profileHandler); // Route 2
```

When a request comes in for `/users/789`:

1. The router first tries the literal `users` segment (from Route 2)
2. Route 2 requires a third segment `/profile`, but the path ends at `789`
3. The router backtracks and tries the parameter `:entity` instead
4. Route 1 matches with `entity=users` and `id=789`

Without backtracking, the request would fail because the router would commit to the literal `users` path and never consider Route 1.

### Backtracking with tail segments

Tail segments (`/**`) act as catch-alls and benefit from backtracking:

```dart
router.get('/files/**', catchAllHandler);           // Route 1
router.get('/files/special/report', reportHandler); // Route 2
```

- `/files/special/report` → matches Route 2 (exact match)
- `/files/special/other` → backtracks to Route 1 (catch-all)

This allows you to define specific routes alongside catch-all routes, with the
specific routes taking priority when they fully match.

## Examples & further reading

### Examples

- **[Basic routing example](https://github.com/serverpod/relic/blob/main/example/routing/basic_routing.dart)** - The complete working example from this guide.

### API documentation

- [RelicApp class](https://pub.dev/documentation/relic/latest/relic/RelicApp-class.html) - Main application class with routing methods.
- [Router class](https://pub.dev/documentation/relic/latest/relic/Router-class.html) - URL router for mapping path patterns.
- [Method enum](https://pub.dev/documentation/relic/latest/relic/Method.html) - HTTP methods enumeration.
