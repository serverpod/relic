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

- **Path parameters (`:id`)** capture named segments and are available via `request.pathParameters`.
- **Wildcards (`*`)** match any single path segment but do not capture a value.
- **Tail segments (`/**`)** capture the rest of the path and expose it through `request.remainingPath`.

### Path parameters (`:id`)

Use a colon-prefixed name to capture a segment. Access the value with the `Symbol`-based key that matches the parameter name.

```dart
final app = RelicApp()
  ..get('/users/:id', (final Request request) {
    final userId = request.pathParameters[#id];
    return Response.ok(
      body: Body.fromString('User $userId'),
    );
  });
```

### Wildcards (`*`)

Use `*` to match any single segment without naming it. This is useful when the value does not matter, such as matching `/files/<anything>/download`.

```dart
app.get('/files/*/download', (final Request request) {
  return Response.ok(body: Body.fromString('Downloading file...'));
});
```

### Tail segments (`/**`)

Use `/**` at the end of a pattern to match the entire remaining path. The unmatched portion is available via `request.remainingPath`.

```dart
app.get('/static/**', (final Request request) {
  final relativeAssetPath = request.remainingPath.toString();
  return Response.ok(
    body: Body.fromString('Serve $relativeAssetPath'),
  );
});
```

Tail segments are required when serving directories so that the handler knows which file the client requested. A route like `/static` without `/**` would not expose the requested child path.

## Examples & further reading

### Examples

- **[Basic routing example](https://github.com/serverpod/relic/blob/main/example/routing/basic_routing.dart)** - The complete working example from this guide.

### API documentation

- [RelicApp class](https://pub.dev/documentation/relic/latest/relic/RelicApp-class.html) - Main application class with routing methods.
- [Router class](https://pub.dev/documentation/relic/latest/relic/Router-class.html) - URL router for mapping path patterns.
- [Method enum](https://pub.dev/documentation/relic/latest/relic/Method.html) - HTTP methods enumeration.
