---
sidebar_position: 3
---

# Basic Routing

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

## Example

Here's a complete working server with routing (see [`basic_routing.dart`](https://github.com/serverpod/relic/blob/main/example/basic_routing.dart)):

```dart
import 'dart:io';
import 'package:relic/io_adapter.dart';
import 'package:relic/relic.dart';

Future<void> main() async {
  final router = Router<Handler>();

  // Define routes
  router.get('/', (ctx) {
    return ctx.respond(
      Response.ok(
        body: Body.fromString('Hello World!'),
      ),
    );
  });

  router.post('/', (ctx) {
    return ctx.respond(
      Response.ok(
        body: Body.fromString('Got a POST request'),
      ),
    );
  });

  router.put('/user', (ctx) {
    return ctx.respond(
      Response.ok(
        body: Body.fromString('Got a PUT request at /user'),
      ),
    );
  });

  router.delete('/user', (ctx) {
    return ctx.respond(
      Response.ok(
        body: Body.fromString('Got a DELETE request at /user'),
      ),
    );
  });

  // Combine router with fallback
  final handler = const Pipeline()
      .addMiddleware(routeWith(router))
      .addHandler(respondWith((_) => Response.notFound()));

  await serve(handler, InternetAddress.anyIPv4, 8080);
  print('Server running on http://localhost:8080');
}
```

## Breaking Down the Routes

The following examples break down each route from the complete example above.

Respond with `Hello World!` on the homepage:

```dart
router.get('/', (ctx) {
  return ctx.respond(Response.ok(body: Body.fromString('Hello World!')));
});
```

Respond to a POST request on the root route (`/`), the application's home page:

```dart
router.post('/', (ctx) {
  return ctx.respond(Response.ok(body: Body.fromString('Got a POST request')));
});
```

Respond to a PUT request to the `/user` route:

```dart
router.put('/user', (ctx) {
  return ctx.respond(Response.ok(body: Body.fromString('Got a PUT request at /user')));
});
```

Respond to a DELETE request to the `/user` route:

```dart
router.delete('/user', (ctx) {
  return ctx.respond(Response.ok(body: Body.fromString('Got a DELETE request at /user')));
});
```

## Summary

Routing is the foundation of any web application. With Relic, you can:

- **Define routes** using `router.METHOD(PATH, HANDLER)` syntax
- **Handle different HTTP methods** - GET, POST, PUT, DELETE, PATCH, etc.
- **Create handlers** that receive context and return responses
- **Combine with middleware** using Pipeline for logging, authentication, etc.
- **Add fallback handlers** for unmatched routes (like 404 pages)

The basic pattern is simple: define your routes, create a pipeline with middleware, and start your server. From here, you can explore advanced features like path parameters, middleware composition, and type-safe request/response handling.

## Examples

- **[`basic_routing.dart`](https://github.com/serverpod/relic/blob/main/example/basic_routing.dart)** - The complete working example from this guide
- **[`requets_response_example.dart`](https://github.com/serverpod/relic/blob/main/example/requets_response_example.dart)** - Comprehensive example covering requests, responses, and advanced routing patterns
