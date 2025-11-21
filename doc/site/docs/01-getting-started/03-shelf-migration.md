---
sidebar_position: 3
sidebar_label: ✈️ Migration from Shelf
---

# Migration from Shelf

This guide helps you migrate from [Shelf](https://github.com/dart-lang/shelf) to Relic. While the core concepts remain similar (handlers, middleware, requests, and responses), Relic introduces improvements in type safety and developer experience that require some changes to your code.

### Why migrate?

Relic was developed to meet the needs of [Serverpod](https://serverpod.dev) for a more modern web server foundation with stronger type safety. Shelf has been an excellent foundation for Dart web servers, but architectural decisions made years ago limit its ability to take advantage of modern Dart features.

## Migration overview

Use this quick plan to get your app running on Relic. The detailed sections below show code for each step.

1. Update dependencies: Remove `shelf`, `shelf_router`, `shelf_web_socket`. Add `relic` to the dependencies.

2. Bootstrap the server: Replace `shelf_io.serve()` with `RelicApp().serve()` if using the io adapter, or integrate RelicApp into your hosting environment as needed.

3. Keep handlers as `Response handler(Request request)`. Handlers in Relic receive a `Request` and return a `Result` (usually a `Response` subclass).

4. Switch to Relic routing: Replace Router from shelf_router with `RelicApp`'s `get`, `post`, `put`, or `delete` methods. Replace `<id>` path parameters with `:id` and read them via `request.pathParameters[#id]`.

5. Create responses with `Body`: Replace `Response.ok('text')` with `Response.ok(body:...)`. Let Relic manage `content-length` and `content-type` through the `Body` class.

6. Replace header access: Replace string lookups like `request.headers['cookie']` with typed accessors such as `request.headers.cookie`.

7. Replace middleware and scoping: Replace `Pipeline().addMiddleware(...)` with `router.use(...)` and attach handlers under that path.

8. Replace `request.context` usage: Replace `request.change(...)` and manual casts with `ContextProperty<T>()`\s .`set` or `get` methods on the context.

9. Update WebSockets: Replace `webSocketHandler` and use `RelicWebSocket` for handling events and sending data.

## Detailed migration steps

### 1. Update dependencies

In your `pubspec.yaml`, remove Shelf packages and add Relic:

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

### 2. Bootstrap the server

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

GITHUB_CODE_BLOCK lang="dart" [src](https://raw.githubusercontent.com/serverpod/relic/main/example/basic/relic_shelf_example.dart) doctag="complete-relic"

### 3. Update handler signatures

Shelf:

```dart
import 'package:shelf/shelf.dart';

Response handler(Request request) {
  return Response.ok('Hello from Shelf!');
}
```

Relic:

```dart
Response handler(Request request) {
  return Response.ok(body: Body.fromString('Hello from Relic!'));
}
```

### 4. Switch to Relic routing

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

```dart
import 'package:relic/relic.dart';

final router = RelicApp()
  ..get('/users/:id', (Request request) {
    final id = request.pathParameters[#id];
    return Response.ok(body: Body.fromString('User $id'));
  });
```

### 5. Create responses with Body

Shelf accepts strings directly and manages headers separately:

```dart
// Shelf - the body can be a plain string.
final response = Response.ok('Hello, World!');

// Content-Type is set separately in headers.
final response = Response.ok(
  '<html>...</html>',
  headers: {'content-type': 'text/html'},
);
```

Relic uses an explicit body type that unifies content, encoding, and MIME type:

```dart
// Relic - explicit Body object is required.
final response = Response.ok(
  body: Body.fromString('Hello, World!'),
);

// Content-Length is automatically calculated and Content-Type and
// encoding are part of the Body.
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
final contentType = request.body.bodyType?.mimeType; // MimeType?
final cookies = request.headers.cookie; // CookieHeader?
final date = request.headers.date; // DateTime?
```

### 7. Replace middleware and scoping

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

```dart
final app = RelicApp()
  ..use('/', logRequests())
  ..use('/api', authentication())
  ..get('/api/users', (Request request) async {
    return Response.ok(body: Body.fromString('User data'));
  });
```

### 8. Replace `request.context` usage

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

```dart
// Relic - Type-safe.
final userProperty = ContextProperty<User>();
final sessionProperty = ContextProperty<Session>();

// Add an extension method for convenient access.
extension AuthContext on Request {
  User get currentUser => userProperty[this];
  Session get session => sessionProperty[this];
}

// Get values in a type-safe way.
final user = request.currentUser;
final session = request.session;
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

Relic has WebSockets built-in without the need for a separate package:

GITHUB_CODE_BLOCK lang="dart" [src](https://raw.githubusercontent.com/serverpod/relic/main/example/basic/relic_shelf_example.dart) doctag="websocket-relic"

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

GITHUB_CODE_BLOCK lang="dart" [src](https://raw.githubusercontent.com/serverpod/relic/main/example/basic/relic_shelf_example.dart) doctag="complete-relic"

:::info Difference from Shelf's pipeline
Unlike Shelf's `Pipeline().addMiddleware()`, which runs for _all_ requests (including 404s), Relic's `.use('/', ...)` only executes middleware for requests that match a route. Unmatched requests (404s) bypass middleware and go directly to the fallback handler.
:::
