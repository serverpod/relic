---
sidebar_position: 3
---

# Basic routing

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

GITHUB_CODE_BLOCK lang="dart" title="GET /" [src](https://raw.githubusercontent.com/serverpod/relic/main/example/routing/basic_routing.dart) doctag="routing-basic-get-root"

**Respond to a POST request on the root route:**

GITHUB_CODE_BLOCK lang="dart" title="POST /" [src](https://raw.githubusercontent.com/serverpod/relic/main/example/routing/basic_routing.dart) doctag="routing-basic-post-root"

**Respond to a PUT request to the `/user` route:**

GITHUB_CODE_BLOCK lang="dart" title="PUT /user" [src](https://raw.githubusercontent.com/serverpod/relic/main/example/routing/basic_routing.dart) doctag="routing-basic-put-user"

**Respond to a DELETE request to the `/user` route:**

GITHUB_CODE_BLOCK lang="dart" title="DELETE /user" [src](https://raw.githubusercontent.com/serverpod/relic/main/example/routing/basic_routing.dart) doctag="routing-basic-delete-user"

### Using the `add` method

This is what the convenience methods call internally:

**Respond to a PATCH request using the core `.add()` method:**

GITHUB_CODE_BLOCK lang="dart" title="PATCH /api" [src](https://raw.githubusercontent.com/serverpod/relic/main/example/routing/basic_routing.dart) doctag="routing-basic-patch-api"

### Using `anyOf` for multiple methods

Handle multiple HTTP methods with the same handler:

**Handle both GET and POST requests to `/admin`:**

GITHUB_CODE_BLOCK lang="dart" title="GET|POST /admin" [src](https://raw.githubusercontent.com/serverpod/relic/main/example/routing/basic_routing.dart) doctag="routing-basic-anyof-admin"

## Example

- **[Basic routing example](https://github.com/serverpod/relic/blob/main/example/routing/basic_routing.dart)** - The complete working example from this guide.
