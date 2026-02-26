---
name: relic-shelf-migration
description: Migrate a Dart web server from Shelf to Relic. Side-by-side reference for every API change. Use when converting Shelf code to Relic, replacing shelf/shelf_router/shelf_web_socket imports, or upgrading an existing server.
---

# Shelf to Relic Migration

Relic replaces `shelf`, `shelf_router`, and `shelf_web_socket` with a single package. Core concepts (handlers, middleware, requests, responses) carry over with improved type safety.

## 1. Dependencies

Remove Shelf packages, add Relic:

```yaml
# Before (Shelf)
dependencies:
  shelf: <version>
  shelf_router: <version>
  shelf_web_socket: <version>

# After (Relic)
dependencies:
  relic: <latest_version>
```

## 2. Server bootstrap

**Shelf:**

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

**Relic:**

```dart
import 'package:relic/relic.dart';

Future<void> main() async {
  final app = RelicApp()
    ..get('/users/:id', (Request request) {
      final id = request.rawPathParameters[#id];
      final name = request.url.queryParameters['name'] ?? 'Unknown';
      return Response.ok(body: Body.fromString('User $id: $name'));
    });

  await app.serve(address: InternetAddress.loopbackIPv4, port: 8080);
}
```

## 3. Handlers

**Shelf:**

```dart
Response handler(Request request) {
  return Response.ok('Hello from Shelf!');
}
```

**Relic:** Handler returns `Result` (usually `Response`). Body requires explicit `Body` object:

```dart
Response handler(Request request) {
  return Response.ok(body: Body.fromString('Hello from Relic!'));
}
```

## 4. Routing

**Shelf:** Path params use `<id>` and are passed as handler arguments:

```dart
final router = Router()
  ..get('/users/<id>', (Request request, String id) {
    return Response.ok('User $id');
  });
```

**Relic:** Path params use `:id` and are read from `request.pathParameters`:

```dart
final router = RelicApp()
  ..get('/users/:id', (Request request) {
    final id = request.pathParameters.raw[#id];
    return Response.ok(body: Body.fromString('User $id'));
  });
```

## 5. Responses with Body

**Shelf:** Accepts plain strings, sets Content-Type via headers map:

```dart
Response.ok('Hello, World!');

Response.ok(
  '<html>...</html>',
  headers: {'content-type': 'text/html'},
);
```

**Relic:** Requires `Body` object. Content-Length is automatic. MIME type is auto-detected or explicit:

```dart
Response.ok(body: Body.fromString('Hello, World!'));

Response.ok(
  body: Body.fromString('<html>...</html>', mimeType: MimeType.html),
);
```

## 6. Headers

**Shelf:** String-based, manual parsing:

```dart
final contentType = request.headers['content-type']; // String?
final cookies = request.headers['cookie'];            // String?
final date = request.headers['date'];                 // String?
```

**Relic:** Type-safe accessors with automatic parsing:

```dart
final contentType = request.body.bodyType?.mimeType;  // MimeType?
final cookies = request.headers.cookie;                // CookieHeader?
final date = request.headers.date;                     // DateTime?
```

## 7. Middleware

**Shelf:** `Pipeline` applies middleware to all requests including 404s:

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

**Relic:** `router.use()` scopes middleware by path and only runs on matched routes:

```dart
final app = RelicApp()
  ..use('/', logRequests())
  ..use('/api', authentication())
  ..get('/api/users', (Request request) async {
    return Response.ok(body: Body.fromString('User data'));
  });
```

Unmatched requests (404s) bypass middleware and go directly to the fallback handler.

## 8. Context

**Shelf:** Dynamic map with manual casting:

```dart
final modifiedRequest = request.change(context: {
  'user': currentUser,
  'session': sessionData,
});

// Later...
final user = request.context['user'] as User?;
```

**Relic:** Type-safe `ContextProperty` with extension methods:

```dart
final userProperty = ContextProperty<User>('user');
final sessionProperty = ContextProperty<Session>('session');

extension AuthContext on Request {
  User get currentUser => userProperty[this];
  Session get session => sessionProperty[this];
}

// Set in middleware
userProperty[req] = authenticatedUser;

// Read in handler -- type-safe, no casting
final user = req.currentUser;
final session = req.session;
```

## 9. WebSockets

**Shelf:** Requires separate `shelf_web_socket` package:

```dart
import 'package:shelf_web_socket/shelf_web_socket.dart';

var handler = webSocketHandler((webSocket) {
  webSocket.stream.listen((message) {
    print('Received: $message');
  });
  webSocket.sink.add('Hello!');
});
```

**Relic:** Built-in, return `WebSocketUpgrade` from any handler:

```dart
WebSocketUpgrade websocketHandler(Request request) {
  return WebSocketUpgrade((ws) async {
    ws.events.listen((event) {
      log('Received: $event');
    });
    ws.trySendText('Hello!');
    ws.sendText('Hello!');
  });
}
```

## Complete side-by-side example

### Shelf

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

### Relic

```dart
import 'package:relic/relic.dart';

Future<void> main() async {
  final app = RelicApp()
    ..use('/', logRequests())
    ..get('/users/:id', (Request request) {
      final id = request.rawPathParameters[#id];
      final name = request.url.queryParameters['name'] ?? 'Unknown';
      return Response.ok(body: Body.fromString('User $id: $name'));
    });

  await app.serve(address: InternetAddress.loopbackIPv4, port: 8080);
}
```

## Quick reference

| Shelf | Relic |
| ----- | ----- |
| `import 'package:shelf/shelf.dart'` | `import 'package:relic/relic.dart'` |
| `shelf_io.serve(handler, host, port)` | `RelicApp().serve(address: addr, port: port)` |
| `Response.ok('text')` | `Response.ok(body: Body.fromString('text'))` |
| `Router()..get('/path/<id>', (req, id) {...})` | `RelicApp()..get('/path/:id', (req) {...})` |
| `request.headers['name']` | `request.headers.name` (typed) |
| `Pipeline().addMiddleware(mw).addHandler(h)` | `app.use('/', mw)` |
| `request.change(context: {...})` | `ContextProperty<T>()[req] = value` |
| `shelf_web_socket` package | Built-in `WebSocketUpgrade` |
