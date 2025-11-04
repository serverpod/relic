---
sidebar_position: 3
---

# Basic routing

_Routing_ refers to determining how an application responds to a client request to a particular endpoint, which is a URI (or path) and a specific HTTP request method (GET, POST, and so on).

Each route can have one or more handler functions, which are executed when the route is matched.

Route definition takes the following structure:

```dart
router.METHOD(PATH, HANDLER)
```

Where:

- `router` is an instance of `Router<Handler>`.
- `METHOD` is an HTTP request method, in lowercase.
- `PATH` is a path on the server.
- `HANDLER` is the function executed when the route is matched.

## The `add` method and syntactic sugar

At the core of routing is the `add` method:

```dart
router.add(Method.get, '/', handler);
```

The convenience methods like `.get()`, `.post()`, `.anyOf()`, and `.any()` are all syntactic sugar that call this underlying `add` method:

- `.get(path, handler)` → `.add(Method.get, path, handler)`
- `.post(path, handler)` → `.add(Method.post, path, handler)`
- `.anyOf({Method.get, Method.post}, path, handler)` → calls `.add()` for each method in the set.
- `.any(path, handler)` → calls `.anyOf()` with all HTTP methods.

## Breaking down the routes

The following examples break down each route from the complete example above.

### Convenience methods (syntactic sugar)

These methods are syntactic sugar for the core `.add()` method:

**Respond with `Hello World!` on the homepage:**

GITHUB_CODE_BLOCK lang="dart" title="basic_routing.dart" [src](https://raw.githubusercontent.com/serverpod/relic/main/example/routing/basic_routing.dart) doctag="routing-basic-get-root"

**Respond to a POST request on the root route:**

GITHUB_CODE_BLOCK lang="dart" title="basic_routing.dart" [src](https://raw.githubusercontent.com/serverpod/relic/main/example/routing/basic_routing.dart) doctag="routing-basic-post-root"

**Respond to a PUT request to the `/user` route:**

GITHUB_CODE_BLOCK lang="dart" title="basic_routing.dart" [src](https://raw.githubusercontent.com/serverpod/relic/main/example/routing/basic_routing.dart) doctag="routing-basic-put-user"

**Respond to a DELETE request to the `/user` route:**

GITHUB_CODE_BLOCK lang="dart" title="basic_routing.dart" [src](https://raw.githubusercontent.com/serverpod/relic/main/example/routing/basic_routing.dart) doctag="routing-basic-delete-user"

### Using the `add` method

This is what the convenience methods call internally:

**Respond to a PATCH request using the core `.add()` method:**

GITHUB_CODE_BLOCK lang="dart" title="basic_routing.dart" [src](https://raw.githubusercontent.com/serverpod/relic/main/example/routing/basic_routing.dart) doctag="routing-basic-patch-api"

### Using `anyOf` for multiple methods

Handle multiple HTTP methods with the same handler:

**Handle both GET and POST requests to `/admin`:**

GITHUB_CODE_BLOCK lang="dart" title="basic_routing.dart" [src](https://raw.githubusercontent.com/serverpod/relic/main/example/routing/basic_routing.dart) doctag="routing-basic-anyof-admin"

## Examples

- **[`basic_routing.dart`](https://github.com/serverpod/relic/blob/main/example/routing/basic_routing.dart)** - The complete working example from this guide.
