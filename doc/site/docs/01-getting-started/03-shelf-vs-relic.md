---
sidebar_position: 3
sidebar_label: 🤔 Shelf vs Relic
---

# Shelf vs Relic

Relic was inspired by [Shelf](https://github.com/dart-lang/shelf), while the core concepts remain similar (handlers, middleware, requests, and responses), Relic introduces improvements in type safety and developer experience.

#### Why a New Framework?

Relic was born out of the needs of [Serverpod](https://serverpod.dev) for a more modern web server foundation with stronger type safety. Shelf has been an excellent foundation for Dart web servers, but certain architectural decisions made years ago limit its ability to take advantage of modern Dart features.

### Key Differences at a Glance

| Feature | Shelf | Relic |
|---------|-------|-------|
| **Type Safety** | Uses `dynamic` in several places | Stronger type safety throughout |
| **Routing** | Requires `shelf_router` package | Built-in trie-based router |
| **Headers** | String-based, manual parsing | Type-safe with validation |
| **WebSockets** | Requires `shelf_web_socket` package (which uses `web_socket_channel`) | Built-in support using `web_socket` |
| **Context Pattern** | `Request` object only | State machine with typed contexts |
| **Body Encoding** | Headers and stream are separate | Unified `Body` type |
| **Path Parameters** | String keys `params['id']` | Symbol-based `ctx.pathParameters[#id]` |
| **Route Matching** | O(routes) linear iteration | O(segments) trie-based |

## Architecture & Philosophy

### Handler Signatures

**Shelf:**

```dart
import 'package:shelf/shelf.dart';

Response handler(Request request) {
  return Response.ok('Hello, Shelf!');
}
```

**Relic:**

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

Relic introduces a **context state machine** that explicitly represents the different states a request can be in (new, responded, hijacked, connected), making state transitions explicit and providing compile-time guarantees.

## Type Safety

### Headers

**Shelf** uses string-based headers with manual parsing:

```dart
// Shelf - string-based, error-prone
final contentType = request.headers['content-type'];
final cookies = request.headers['cookie']?.split('; ') ?? [];
final date = request.headers['date']; // Returns String?
```

**Relic** provides type-safe headers with automatic validation:

```dart
final contentType = response.body.bodyType?.mimeType;
final cookies = request.headers.cookie;
final date = request.headers.date;
```

### Body Handling

Both frameworks have similar methods for **reading** request bodies:

```dart
final body = await request.readAsString();
final stream = request.read();
```

The key difference is in **creating responses**:

**Shelf** accepts strings directly and manages headers separately:

```dart
// Shelf - body can be a plain string
final response = Response.ok('Hello, World!');

// Content-Type is set separately in headers
final response = Response.ok(
  '<html>...</html>',
  headers: {'content-type': 'text/html'},
);
```

**Relic** uses an explicit `Body` type that unifies content, encoding, and MIME type:

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

This unified approach in Relic ensures the body content, encoding, content-type header, and content-length header stay in sync, reducing errors.

Relic will attempt to infer the MIME type if not set explicitly, but it's best practice to set it explicitly when known to avoid running the detection code. The detection works best for binary content, though it can handle some textual content such as HTML, XML, and JSON. The inference is optimized for speed over precision.

## Routing

### Basic Routing

**Shelf** requires the separate `shelf_router` package:

```dart
import 'package:shelf/shelf.dart';
import 'package:shelf_router/shelf_router.dart';

final router = Router()
  ..get('/users/<id>', (Request request, String id) {
    return Response.ok('User $id');
  });
```

**Relic** has routing built-in:

```dart
import 'package:relic/relic.dart';

final router = RelicApp()
  ..get('/users/:id',(NewContext ctx) {
    final id = ctx.pathParameters[#id];
    return ctx.respond(Response.ok(body: Body.fromString('User $id')));
  },
);
```

### Routing Performance

Shelf's router (from `shelf_router`) iterates through routes linearly—O(routes) complexity. Relic uses a [trie data structure](https://en.wikipedia.org/wiki/Trie) for O(segments) matching, which should be faster for applications with many routes.

### Middleware on Routes

**Shelf** applies middleware globally via `Pipeline`:

```dart
final handler = Pipeline()
  .addMiddleware(logRequests())
  .addMiddleware(authentication())
  .addHandler(router);
```

**Relic** allows middleware at the route level with `router.use()`:

```dart
  final router = RelicApp();

  // Apply middleware to specific paths
  router.use('/api', (handler) {
    ...
  });

  // Routes under /api automatically get the middleware
  router.get('/api/users', getUsersHandler);
```

## WebSocket Support

### WebSocket Integration

**Shelf** requires a separate package:

```dart
import 'package:shelf_web_socket/shelf_web_socket.dart';

var handler = webSocketHandler((webSocket) {
  webSocket.stream.listen((message) {
    print('Received: $message');
  });
  webSocket.sink.add('Hello!');
});
```

**Relic** has WebSockets built-in with state machine integration:

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

Relic's WebSocket API integrates with the context state machine and provides both throwing and non-throwing send methods for better error handling. Unlike Shelf's `shelf_web_socket` package (which uses the older (`web_socket_channel`)[https://pub.dev/packages/web_socket_channel]), Relic uses the modern (`web_socket`)[https://pub.dev/packages/web_socket] package for better performance and a more idiomatic Dart API.

## State Management

### Request-Scoped State

**Shelf** uses a context map with string keys:

```dart
// Shelf - type-unsafe
final modifiedRequest = request.change(context: {
  'user': currentUser,
  'session': sessionData,
});

// Later...
final user = request.context['user'] as User?;  // Manual casting
```

**Relic** uses type-safe `ContextProperty`:

```dart
// Relic - type-safe
final userProperty = ContextProperty<User>();
final sessionProperty = ContextProperty<Session>();

// Set values
userProperty.set(ctx, currentUser);
sessionProperty.set(ctx, sessionData);

// Get values - type-safe!
final user = userProperty.get(ctx);  // User?
final session = sessionProperty.get(ctx);  // Session?

```

Since `ContextProperty` objects are separate instances, there's no risk of key conflicts between different properties, unlike string-based context maps.

## State Machine

**Relic** uses a state machine where handlers **must** return a handled context:

```dart
ResponseContext handler(NewContext ctx) {
  // Must return ResponseContext, HijackContext, or ConnectContext
  return ctx.respond(Response.ok());
}
```

This eliminates entire classes of errors at compile time.

## Design Choices

Relic includes several design decisions aimed at performance and type safety:

1. **Trie-based routing**: O(segments) vs O(routes) complexity for route matching
2. **Type specialization**: Eliminates runtime type checks in many cases
3. **Unified body representation**: Keeps content, encoding, and headers in sync

:::note
We haven't yet conducted comprehensive benchmarks comparing Relic to Shelf overall. While our CI runs confirm the router is fast, routing is only one part of total request handling performance.
:::

## Migration Considerations

While Relic is not backward compatible with Shelf, migration is straightforward for most applications:

- Handler signatures change to use contexts
- String-based headers become type-safe accessors
- `shelf_router` routes map directly to Relic's built-in router
- `shelf_web_socket` becomes built-in WebSocket support
- `request.change(context: {...})` becomes `ContextProperty`

## When to Use Each

**Use Shelf if:**

- You need maximum ecosystem compatibility
- You're maintaining an existing Shelf application
- You prefer the simpler mental model of `Request → Response`

**Use Relic if:**

- You want maximum type safety and compile-time guarantees
- You have many routes and want trie-based routing
- You want built-in WebSocket support
- You prefer explicit state management with the context pattern
- You're building a new application or can afford migration

## Example Comparison

Here's a complete example showing the differences:

### Shelf Version

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

### Relic Version

```dart
import 'dart:io';
import 'package:relic/io_adapter.dart';
import 'package:relic/relic.dart';

void main() async {
  final router = RelicApp()
    ..get(
      '/users/:id',
      (NewContext ctx) {
        final id = ctx.pathParameters[#id]!;
        final name = ctx.request.url.queryParameters['name'] ?? 'Unknown';
        return ctx.respond(
          Response.ok(body: Body.fromString('User $id: $name')),
        );
      },
    );

  await router.serve(port: 8080);
}
```

## Learn More

- [Shelf Documentation](https://pub.dev/packages/shelf)
- [Relic on GitHub](https://github.com/serverpod/relic)
- [Serverpod](https://serverpod.dev)
