---
sidebar_position: 3
sidebar_label: 🤔 Shelf vs Relic
---

# Shelf vs Relic

Relic was inspired by [Shelf](https://github.com/dart-lang/shelf), while the core concepts remain similar (handlers, middleware, requests, and responses), Relic introduces significant improvements in type safety, performance, and developer experience.

## Why a New Framework?

Relic was born out of the needs of [Serverpod](https://serverpod.dev) for a more modern and performant web server foundation. Shelf has been an excellent foundation for Dart web servers, but certain architectural decisions made years ago limit its ability to take advantage of modern Dart features and optimizations.

## Key Differences at a Glance

| Feature | Shelf | Relic |
|---------|-------|-------|
| **Type Safety** | Uses `dynamic` in several places | Fully type-safe, no `dynamic` |
| **Byte Handling** | `List<int>` | `Uint8List` (more efficient) |
| **Routing** | Requires `shelf_router` package | Built-in trie-based router |
| **Headers** | String-based, manual parsing | Type-safe with validation |
| **WebSockets** | Requires `shelf_web_socket` package | Built-in support |
| **Context Pattern** | `Request` object only | State machine with typed contexts |
| **Body Encoding** | Headers and stream are separate | Unified `Body` type |
| **Path Parameters** | String keys `params['id']` | Symbol-based `ctx.pathParameters[#id]` |
| **Performance** | O(routes) matching | O(segments) with trie structure |

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

Relic introduces a **context state machine** that explicitly represents the different states a request can be in (new, responded, hijacked, connected), eliminating ambiguity and providing compile-time guarantees.

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
// Relic - type-safe with validation
final contentType = request.headers.contentType;  // MediaType?
final cookies = request.headers.cookie;            // List<Cookie>
final date = request.headers.date;                 // DateTime?
```

### Body Handling

Both frameworks have similar methods for **reading** request bodies:

```dart
// Both Shelf and Relic
final body = await request.readAsString();
final stream = request.read();  // Stream<Uint8List> in Relic, Stream<List<int>> in Shelf
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

final router = Router<Handler>()
  ..get('/users/:id', (RequestContext ctx) {
    final id = ctx.pathParameters[#id];  // Symbol-based access
    return ctx.respond(Response.ok(body: Body.fromString('User $id')));
  });
```

### Performance

Shelf's router (from `shelf_router`) iterates through routes linearly—O(routes) complexity. Relic uses a [trie data structure](https://en.wikipedia.org/wiki/Trie) for O(segments) matching, which is significantly faster for applications with many routes.

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
final router = Router<Handler>();

// Apply middleware to specific paths
router.use('/api', (handler) {
  return (ctx) async {
    // Auth check
    if (!isAuthorized(ctx)) {
      return ctx.respond(Response.forbidden());
    }
    return handler(ctx);
  };
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

Relic's WebSocket API integrates seamlessly with the context state machine and provides both throwing and non-throwing send methods for better error handling.

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

## Error Handling

**Shelf** may return `null` from handlers, requiring adapters to handle this case:

```dart
Response? handler(Request request) {
  // Could return null
  return null;
}
```

**Relic** uses a state machine where handlers **must** return a handled context:

```dart
ResponseContext handler(NewContext ctx) {
  // Must return ResponseContext, HijackContext, or ConnectContext
  return ctx.respond(Response.ok());
}
```

This eliminates entire classes of errors at compile time.

## Performance Optimizations

Relic includes several performance improvements:

1. **`Uint8List` instead of `List<int>`**: More efficient byte handling
2. **Trie-based routing**: O(segments) vs O(routes) complexity
3. **Path normalization caching**: LRU cache for common paths
4. **Type specialization**: Eliminates runtime type checks
5. **Unified body representation**: Fewer conversions between types

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
- You need high-performance routing with many routes
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
  final router = Router<Handler>()
    ..get('/users/:id', (RequestContext ctx) {
      final id = ctx.pathParameters[#id]!;
      final name = ctx.request.url.queryParameters['name'] ?? 'Unknown';
      return ctx.respond(
        Response.ok(body: Body.fromString('User $id: $name')),
      );
    });

  final handler = Pipeline()
      .addMiddleware(logRequests())
      .addMiddleware(routeWith(router))
      .addHandler(respondWith((_) => Response.notFound()));

  await serve(handler, InternetAddress.anyIPv4, 8080);
}
```

## Learn More

- [Shelf Documentation](https://pub.dev/packages/shelf)
- [Shelf Router](https://pub.dev/packages/shelf_router)
- [Relic on GitHub](https://github.com/serverpod/relic)
- [Serverpod](https://serverpod.dev)
