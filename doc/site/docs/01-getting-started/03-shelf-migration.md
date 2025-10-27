---
sidebar_position: 3
sidebar_label: ✈️ Migration from Shelf
---

# Migration from Shelf

This guide helps you migrate from [Shelf](https://github.com/dart-lang/shelf) to Relic. While the core concepts remain similar (handlers, middleware, requests, and responses), Relic introduces improvements in type safety and developer experience that require some changes to your code.

### Why migrate?

Relic was born out of the needs of [Serverpod](https://serverpod.dev) for a more modern web server foundation with stronger type safety. Shelf has been an excellent foundation for Dart web servers, but certain architectural decisions made years ago limit its ability to take advantage of modern Dart features.

## Migration overview

Use this quick plan to get your app running on Relic. The detailed sections below show code for each step.

1) ✅ Update dependencies: Remove `shelf`, `shelf_router`, `shelf_web_socket`. Add `relic` to the dependencies.

2) ✅ Bootstrap the server: Replace `shelf_io.serve()` with `RelicApp().serve()` if using the io adapter, or integrate RelicApp into your hosting environment as needed.

3) ✅ Update handler signatures: Change from `Response handler(Request request)` to use either `respondWith` or `ResponseContext handler(NewContext ctx)`.

4) ✅ Switch to Relic routing: Replace Router from shelf_router with `RelicApp().get/post/put/delete`. Replace `<id>` path params with `:id` and read them via `ctx.pathParameters[#id]`.

5) ✅ Create responses with Body: Replace `Response.ok('text')` with `Response.ok(body:...)`. Let Relic manage content-length and content-type through Body.

6) ✅ Replace header access: Replace string lookups like `request.headers['cookie']` with typed accessors such as `request.headers.cookie`.

7) ✅ Replace middleware and scoping: Replace `Pipeline().addMiddleware(...)` with `router.use(...)` and attach handlers under that path.

8) ✅ Replace request.context usage: Replace `request.change(...)` and manual casts with `ContextProperty<T>().set/get` on the context.

9) ✅ Update WebSockets: Replace `webSocketHandler` and use `RelicWebSocket` for events and sending.

10) ✅ Satisfy the state machine: Handlers must return a handled context.

## Detailed migration steps

### 1. Update dependencies

In your `pubspec.yaml`, remove Shelf packages and add Relic:

Before:

```yaml
dependencies:
  shelf: <shelf_version>
  shelf_router: <shelf_router_version>
  shelf_web_socket: <shelf_web_socket_version>
```

After:

```yaml
dependencies:
  relic: <latest_version>
```

### 2. Bootstrap the server

Before (Shelf):

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

After (Relic):

```dart
import 'package:relic/io_adapter.dart';
import 'package:relic/relic.dart';

void main() async {
  final app = RelicApp();
  // Add routes...
  await app.serve(port: 8080);
}
```

### 3. Update handler signatures

Before (Shelf):

```dart
import 'package:shelf/shelf.dart';

Response handler(Request request) {
  return Response.ok('Hello, Shelf!');
}
```

After (Relic):

```dart
import 'package:relic/relic.dart';

// Using the Responder pattern
Handler handler = respondWith((Request request) {
  return Response.ok(body: Body.fromString('Hello, Relic!'));
});

// Or using full context
ResponseContext handler(NewContext ctx) {
  return ctx.respond(
    Response.ok(body: Body.fromString('Hello, Relic!')),
  );
}
```

:::tip
Relic introduces a context state machine that explicitly represents the different states a request can be in (new, responded or connected), making state transitions explicit and providing compile-time guarantees. Read more about the context state machine in the [context documentation](../reference/context).
:::

### 4. Switch to Relic routing

Before (Shelf), requires separate package:

```dart
import 'package:shelf/shelf.dart';
import 'package:shelf_router/shelf_router.dart';

final router = Router()
  ..get('/users/<id>', (Request request, String id) {
    return Response.ok('User $id');
  });
```

After (Relic), routing built-in:

```dart
import 'package:relic/relic.dart';

final router = RelicApp()
  ..get('/users/:id', (NewContext ctx) {
    final id = ctx.pathParameters[#id];
    return ctx.respond(Response.ok(body: Body.fromString('User $id')));
  });
```

### 5. Create responses with Body

Shelf accepts strings directly and manages headers separately:

```dart
// Shelf - body can be a plain string
final response = Response.ok('Hello, World!');

// Content-Type is set separately in headers
final response = Response.ok(
  '<html>...</html>',
  headers: {'content-type': 'text/html'},
);
```

Relic uses an explicit Body type that unifies content, encoding, and MIME type:

```dart
// Relic - explicit Body object required
final response = Response.ok(
  body: Body.fromString('Hello, World!'),
);

// Content-Length is automatically calculated
// Content-Type and encoding are part of the Body
final response = Response.ok(
  body: Body.fromString('<html>...</html>', mimeType: MimeType.html),
);
```

### 6. Replace header access

Shelf uses string-based headers with manual parsing:

```dart
final contentType = request.headers['content-type']; // String?
final cookies = request.headers['cookie']; // String?
final date = request.headers['date']; // String?
```

Relic provides type-safe headers with automatic validation:

```dart
final contentType = ctx.request.body.bodyType?.mimeType; // MimeType?
final cookies = ctx.request.headers.cookie; // CookieHeader?
final date = ctx.request.headers.date; // DateTime?
```

### 7. Replace middleware and scoping

Before (Shelf), global middleware via Pipeline:

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

After (Relic), route-level middleware:

```dart
final app = RelicApp()
  ..use('/', logRequests())
  ..use('/api', authentication())
  ..get('/api/users', (NewContext ctx) async {
    return ctx.respond(Response.ok(
      body: Body.fromString('User data'),
    ));
  });
```

### 8. Replace request.context usage

Before (Shelf), context map with string keys:

```dart
// Shelf - type-unsafe
final modifiedRequest = request.change(context: {
  'user': currentUser,
  'session': sessionData,
});

// Later...
final user = request.context['user'] as User?;  // Manual casting
```

After (Relic), type-safe ContextProperty:

```dart
// Relic - type-safe
final userProperty = ContextProperty<User>();
final sessionProperty = ContextProperty<Session>();

// Add an extension method for convenient access
extension AuthContext on RequestContext {
  User get currentUser => userProperty[this];
  Session get session => sessionProperty[this];
}

// Get values - type-safe
final user = ctx.currentUser;
final session = ctx.session;
```

### 9. Update WebSockets

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

Relic has WebSockets built-in with state machine integration:

```dart
import 'package:relic/relic.dart';

ConnectContext handler(NewContext ctx) {
  return ctx.connect((RelicWebSocket ws) {
    ws.events.listen((event) {
      print('Received: $event');
    });

    // Non-throwing variant - returns false if connection closed
    ws.trySendText('Hello!');

    // Or use the throwing variant if you want exceptions
    ws.sendText('Hello!');
  });
}
```

### 10. Satisfy the state machine

Relic uses a state machine where handlers must return a handled context:

```dart
ResponseContext handler(NewContext ctx) {
  return ctx.respond(Response.ok());
}
```

## Example comparison

Here is a complete example showing the differences between Shelf and Relic.

### Shelf version

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

### Relic version

```dart
import 'package:relic/io_adapter.dart';
import 'package:relic/relic.dart';

void main() async {
  final app = RelicApp()
    ..use('/', logRequests()) // Apply logging to all routes
    ..get('/users/:id', (NewContext ctx) {
      final id = ctx.pathParameters[#id]!;
      final name = ctx.request.url.queryParameters['name'] ?? 'Unknown';
      return ctx.respond(
        Response.ok(body: Body.fromString('User $id: $name')),
      );
    });

  await app.serve();
}
```

:::info Difference from Shelf's pipeline
Unlike Shelf's `Pipeline().addMiddleware()`, which runs for _all_ requests (including 404s), Relic's `.use('/', ...)` only executes middleware for requests that match a route. Unmatched requests (404s) bypass middleware and go directly to the fallback handler.
:::
