---
sidebar_position: 3
sidebar_label: ✈️ Migration from Shelf
---

# Migration from Shelf

This guide helps you move a server from [Shelf](https://github.com/dart-lang/shelf) to Relic. The two share their core concepts, handlers, middleware, requests and responses, so most of the work is changing types and names. The steps below go through the changes one at a time, each with the Shelf code first and the Relic code after it.

## The steps at a glance

1. Replace the `shelf`, `shelf_router` and `shelf_web_socket` dependencies with `relic`.
2. Serve the app with `RelicApp().serve()` instead of `shelf_io.serve()`.
3. Keep handlers as functions from a `Request` to a `Response`.
4. Register routes on a `RelicApp`, with `:id` parameters in place of `<id>`.
5. Give each response a `Body`, and set its type there rather than in the headers.
6. Read headers through typed accessors instead of strings.
7. Attach middleware to paths with `use` instead of composing a `Pipeline`.
8. Replace the request context map with typed context properties.
9. Return a `WebSocketUpgrade` instead of using `shelf_web_socket`.

## 1. Update dependencies

In `pubspec.yaml`, remove the Shelf packages and add Relic.

Shelf:

```yaml
dependencies:
  shelf: <shelf_version>
  shelf_router: <shelf_router_version>
  shelf_web_socket: <shelf_web_socket_version>
```

Relic:

```yaml
dependencies:
  relic: <latest_version>
```

One package replaces three, since routing and WebSockets are part of Relic. The [Installation](./01-installation.md) page says which version to pick.

## 2. Bootstrap the server

Shelf:

```dart
import 'package:shelf_router/shelf_router.dart';
import 'package:shelf/shelf.dart';
import 'package:shelf/shelf_io.dart' as io;

void main() async {
  final app = Router();
  // Add routes...
  await io.serve(app, 'localhost', 8080);
}
```

Relic:

GITHUB_CODE_BLOCK lang="dart" file="../_example/basic/relic_shelf.dart" doctag="complete-relic" title="A Relic server with one route"

`RelicApp` is the router and the application in one, and `serve` starts it, here on port 8080 of the loopback address, which is also where it listens when given no arguments. This program already has a route and logging, which the steps below explain.

## 3. Update handler signatures

Shelf:

```dart
import 'package:shelf/shelf.dart';

Response handler(Request request) {
  return Response.ok('Hello from Shelf!');
}
```

Relic:

GITHUB_CODE_BLOCK lang="dart" file="../_example/basic/relic_shelf.dart" doctag="shelf-relic-handler" title="The same handler in Relic"

The signature stays the same, a function from a `Request` to a `Response`. What changes is the body of the response, which step 5 covers. A Relic handler may also return the other kinds of `Result`, which the [Handlers](../02-reference/01-handlers.md) page describes, but a handler that returns a `Response` needs nothing more.

## 4. Switch to Relic routing

Shelf:

```dart
import 'package:shelf/shelf.dart';
import 'package:shelf_router/shelf_router.dart';

final router = Router()
  ..get('/users/<id>', (Request request, String id) {
    return Response.ok('User $id');
  });
```

Relic:

GITHUB_CODE_BLOCK lang="dart" file="../_example/basic/relic_shelf.dart" doctag="shelf-relic-routing" title="A route with a parameter"

A parameter is written `:id` instead of `<id>`. Its value no longer arrives as an extra argument to the handler. The handler reads it from the request, by the parameter's name as a Dart symbol, `#id`. Typed accessors can also parse it into a number or any other type, as the [Routing](../02-reference/03-routing.md#path-parameters) page shows.

## 5. Create responses with Body

Shelf accepts strings directly and manages headers separately:

```dart
// Shelf - the body can be a plain string.
final textResponse = Response.ok('Hello, World!');

// Content-Type is set separately in headers.
final htmlResponse = Response.ok(
  '<html>...</html>',
  headers: {'content-type': 'text/html'},
);
```

Relic puts the content, its encoding and its type together in a `Body`:

GITHUB_CODE_BLOCK lang="dart" file="../_example/basic/relic_shelf.dart" doctag="shelf-relic-responses" title="Responses with a Body"

A `content-type` or `content-length` that Shelf code puts in the response headers has no effect in Relic, because the body decides both. Move them to the `Body`. The [Body](../02-reference/06-body.md) page shows what each kind of body decides.

## 6. Replace header access

Shelf uses string-based headers with manual parsing:

```dart
final contentType = request.headers['content-type']; // String?
final cookies = request.headers['cookie']; // String?
final date = request.headers['date']; // String?
```

Relic has a typed accessor for each common header:

GITHUB_CODE_BLOCK lang="dart" file="../_example/basic/relic_shelf.dart" doctag="shelf-relic-headers" title="Typed headers"

Each accessor parses its header into a value of the right type. When a header does not parse, reading it throws, and Relic answers the request with 400. A header without an accessor is still there by name, as `request.headers['x-custom']`.

## 7. Replace middleware and scoping

Shelf:

```dart
final app = Router()
  ..get('/api/users', (Request request) {
    return Response.ok('User data');
  });

final handler = Pipeline()
  .addMiddleware(logRequests())
  .addMiddleware(authentication())
  .addHandler(app);
```

Relic:

GITHUB_CODE_BLOCK lang="dart" file="../_example/basic/relic_shelf.dart" doctag="shelf-relic-middleware" title="Middleware attached to paths"

`use` attaches middleware to a path in the router, so authentication can cover `/api` while logging covers everything. One difference matters for a logger. Shelf's `Pipeline().addMiddleware()` runs middleware for every request, 404s included, while Relic's `use` runs it only for requests that match a route. The [Middleware](../02-reference/08-middleware.md#which-requests-middleware-sees) page shows how to reach every request, and Relic also has a `Pipeline` of its own, described on the [Pipeline](../02-reference/99-pipeline.md) page.

## 8. Replace `request.context` usage

Shelf:

```dart
// Shelf - Dynamic types.
final modifiedRequest = request.change(context: {
  'user': currentUser,
  'session': sessionData,
});

// Later...
final user = request.context['user'] as User?;  // Manual casting
```

Relic:

GITHUB_CODE_BLOCK lang="dart" file="../_example/basic/relic_shelf.dart" doctag="shelf-relic-context" title="Typed context properties"

A `ContextProperty` is a typed slot on every request. A middleware sets it with `property[request] = value`, and a handler reads it with `property.get(request)`, or with `property[request]` when the value may be absent. No new request is made and no cast is needed. The [Context properties](../02-reference/02-context.md) page explains why each property is created once, as a global.

## 9. Update WebSockets

Shelf requires a separate package:

```dart
import 'package:shelf_web_socket/shelf_web_socket.dart';

var handler = webSocketHandler((webSocket) {
  webSocket.stream.listen((message) {
    print('Received: $message');
  });
  webSocket.sink.add('Hello!');
});
```

In Relic, a handler returns a `WebSocketUpgrade`:

GITHUB_CODE_BLOCK lang="dart" file="../_example/basic/relic_shelf.dart" doctag="websocket-relic" title="A WebSocket handler"

`webSocketHandler` accepts a browser connection from any origin unless you pass `allowedOrigins`. Relic refuses an upgrade from a page on another origin with 403. Set `allowAnyOrigin: true` on the `WebSocketUpgrade` only for an endpoint meant to be opened by other sites, and that does not authenticate with cookies.

## A complete example

Here is a small server in Shelf, with one route, a query parameter and logging:

```dart
import 'package:shelf/shelf.dart';
import 'package:shelf_router/shelf_router.dart';
import 'package:shelf/shelf_io.dart' as shelf_io;

void main() async {
  final router = Router()
    ..get('/users/<id>', (Request request, String id) {
      final name = request.url.queryParameters['name'] ?? 'Unknown';
      return Response.ok('User $id: $name');
    });

  final handler = Pipeline()
      .addMiddleware(logRequests())
      .addHandler(router);

  await shelf_io.serve(handler, 'localhost', 8080);
}
```

And here it is in Relic:

GITHUB_CODE_BLOCK lang="dart" file="../_example/basic/relic_shelf.dart" doctag="complete-relic" title="The same server in Relic"

It answers the same way:

```bash
curl 'http://localhost:8080/users/42?name=Nova'
curl http://localhost:8080/users/7
```

```text
User 42: Nova
User 7: Unknown
```

and it logs each request:

```text
2026-10-23T14:21:16.388161  0:00:00.007249 GET     [200] /users/42?name=Nova
2026-10-23T14:21:16.446968  0:00:00.001342 GET     [200] /users/7
```
