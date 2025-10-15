# A Relic on a Shelf

Relic started life as a subcomponent of Serverpod. It would sit next to your generated endpoints serving more mundane assets, such as files, and web widgets inflated from mustache templates or otherwise.

It was always somewhat orthogonal to Serverpod's primary purpose, of enabling a great workflow for creating backend services. Yet it became apparent that it was an important piece of the puzzle for  building complete solutions with serverpod.

Relic was in need of some love if it was to succeed, and we at Serverpod started looking for a potential replacement. An obvious candidate being the venerable Shelf package.

## Why not just shelf?

Shelf has been hugely successful in the Dart eco-system. However, Shelf has been around for a long time. Its first commit (by kevmoo himself) is from April 1st 2014. It stems from a time before Dart had a sound type system, or null safety, and predates the first commit to Flutter by 1.5 years.

There are some early design decisions that feels out of place with modern Dart, that still exists to this day. And - as Flutter eventually took center stage - it seems to have slipped into maintenance mode.

So a decision was made to fork Shelf and re-vamp it for modern Dart, focussing on type safety, and developer experience in general.

For historical reasons, it wasn't created as a GitHub fork but from a source copy, though it did truly start as a fork.

## What does Relic do different?

Development took longer than anticipated - we announced the intention in March 2024, but the first commit landed in December that same year. This gave us time to get the architecture right.

### Handlers and the RequestContext

Relic handlers differ from Shelf handlers. In shelf we have
```dart
typedef Handler = FutureOr<Response> Function(Request request);
```
while in Relic you see:
```dart
typedef Handler = FutureOr<HandledContext> Function(NewContext ctx);
```
This seems more complex, why the added complexity? The problem is that not everything follows the request response model. Today we have web-sockets, server-side events, etc. that hijacks the underlying socket of a request, and hands lifetime handling to the developer.

Shelf does support hijacking, but it does so by using exceptions for control flow. It will throw an exception `HijackException` that is only supposed to be caught and handled by a Shelf adaptor.

As we consider using exceptions for control flow an anti-pattern, we have opted for introducing a `RequestContext` and an associated state machine instead.

The state machine uses sealed classes to model the request lifecycle:

- **`NewContext`** - The initial state when a request arrives. Can transition to any handled state.
- **`HandledContext`** - A sealed base class for all terminal states.
  - **`ResponseContext`** - Normal HTTP response flow
  - **`HijackContext`** - Low-level socket hijacking
  - **`ConnectContext`** - WebSocket or duplex connections

Instead of throwing exceptions, handlers explicitly return the appropriate context type:

```dart
Handler webSocketHandler = (NewContext ctx) {
  if (shouldUpgradeToWebSocket(ctx.request)) {
    return ctx.connect((webSocket) {
      // Handle WebSocket connection
    });
  }
  return ctx.respond(Response.ok());
};
```

The type system guarantees that adapters handle all possible states at compile time through exhaustive pattern matching on the sealed `HandledContext` type. Each request maintains a unique token that persists across state transitions, enabling type-safe request-scoped state via `ContextProperty` (see below).

This approach eliminates the need for `HijackException` and makes the control flow explicit and type-safe.

### Strict typing

One of the things we set out to do was increasing safety by using strict typing as much as possible.
Historically Shelf has used dynamic typing in many places. This is still evident today where fx. headers can be either `String` or `List<String>`, but since Dart doesn't have true union types the declared type is `Object`.

> **Note**: Dart has sealed classes, but they fall a bit short here.

In `Relic` a raw header value is always an `Iterable<String>` and you don't typically interact with raw headers at all, instead using typed accessors.

Instead of:
```dart
updateHeader(headers, {'Cache-Control': 'max-age: 3600'}); // in shelf
```
you do:
```dart
headers.transform((mh) => mh.cacheControl = CacheControlHeader(maxAge: 3600)); // in relic
```
A bit longer, but fully type safe

> **Note:** You can add your own typed headers by using the generic `HeaderAccessor` class and defining an extension method on `Headers`.
>
> Most standard headers should be supported out-of-the-box.

Safety, including type safety is driving goal for us, so we will continue to expand on this in Relic.

### Where is my bag?

In shelf you can store request specific state on in the context bag of the request. This is simply a `Map<String, Object>` so again no type safety, and you risk name conflicts on entries as well.

In Relic we instead introduced the generic `ContextProperty<T>` which you can use to attach type-safe state to a request. Your context property can be private to the package that defines it, and you control how it is accessed by adding extension methods on the `RequestContext` class. This ensures type safety and prevents name conflicts.

Here's how it works:

```dart
// Define a private context property for storing the current user. No name conflict possible.
final _currentUser = ContextProperty<User>('currentUser'); // just a debug name

// Add an extension method for convenient access
extension AuthContext on RequestContext {
  User get currentUser => _currentUser[this];
}

// Use it in middleware
Middleware authMiddleware() {
  return (Handler innerHandler) {
    return (RequestContext ctx) {
      final token = ctx.request.headers.authorization?.credentials;
      final user = validateToken(token);
      _currentUser[ctx] = user;  // Type-safe assignment
      return innerHandler(ctx);
    };
  };
}

// Access it in handlers
Handler protectedResource = (RequestContext ctx) {
  final user = ctx.currentUser;  // Type-safe access, no casting needed
  return (ctx as RespondableContext).respond(
    Response.ok(body: Body.fromString('Hello ${user.name}'))
  );
};
```

**Comparison to Shelf:**

In Shelf, you'd use the context bag:
```dart
// Shelf approach - no type safety, potential name conflicts
request = request.change(context: {'user': user});  // Set is inherently unsafe (untyped)
final user = request.context['user'] as User;       // Get (runtime cast can fail)
```

**Advantages of ContextProperty:**
- **Type safety:** Compile-time checking, no runtime casts
- **No name conflicts:** Each `ContextProperty` instance has isolated storage via `Expando`
- **Privacy control:** Properties can be private to your package
- **Better errors:** Clear `StateError` with debug name when value not found
- **Discoverability:** Extension methods show up in IDE autocomplete

### Routing

Shelf doesn't mandate any particular routing. It has the `shelf_router` (and `shelf_router_generator` packages), which while flexible, basically does a linear scan over the registered routes when dispatching incoming requests. You need a lot of registered routes, and evil parameter extraction, to notice the performance degrade, but we believed we could improve on this.

Also, sub-routers are kind of annoying to setup in Shelf.

So we built a proper trie-based router with support for dynamic parameters (`/:id/`), wildcards (`/*/`), and tail segments (`/**`).

#### Performance: O(segments) vs O(routes)

Unlike `shelf_router` which performs a linear scan over registered routes, Relic's trie-based router looks up handlers in O(n) time where n is the number of path segments (typically 2-5), regardless of how many routes you've registered.

```dart
// Trie lookup: O(segments) - typically ~3-5 operations
router.lookup(Method.get, '/api/v1/users/123/posts');

// shelf_router: O(routes) - must check every route until match
// Gets slower as you add more routes
```

Path normalization is cached using an LRU cache, so common paths like `/api/users` are interned and reused, avoiding repeated parsing.

#### PathMiss vs MethodMiss

The router distinguishes between two types of lookup failures:

```dart
sealed class LookupResult<T> {}

final class PathMiss<T> extends LookupResult<T> {
  // Path doesn't exist - return 404 Not Found
}

final class MethodMiss<T> extends LookupResult<T> {
  final Set<Method> allowed;  // Path exists but wrong method
  // Return 405 Method Not Allowed with Allow header
}

final class RouterMatch<T> extends LookupResult<T> {
  // Successful match
}
```

This enables proper HTTP semantics - your application can automatically return 405 with an `Allow` header when a path exists but the method is wrong, rather than incorrectly returning 404.

#### Router Composition

Routers compose easily with `attach()` and `group()`:

```dart
// Create sub-routers
final apiRouter = RelicRouter();
apiRouter.get('/users', listUsers);
apiRouter.post('/users', createUser);

// Attach to main router
final mainRouter = RelicRouter();
mainRouter.attach('/api', apiRouter);

// Or use group() for inline composition
final router = RelicRouter();
final api = router.group('/api');
api.get('/users', listUsers);

// Nested groups work too
final v1 = api.group('/v1');
v1.get('/posts', listPosts);  // Accessible at /api/v1/posts

// Sub-routers can be created in separate packages for modularity
```

#### Symbol-based Path Parameters

Path parameters use symbols instead of strings:

```dart
router.get('/users/:id/posts/:postId', (RequestContext ctx) {
  final userId = ctx.pathParameters[#id];      // Symbol, not string
  final postId = ctx.pathParameters[#postId];
});
```

Symbols enforce valid identifier syntax and provide cleaner syntax than string literals.

### Performance Optimizations

Beyond API improvements, Relic includes several foundational performance enhancements:

#### Explicit Uint8List Types

While Shelf uses `Uint8List` at runtime (since v1.1.1), its type signature declares `Stream<List<int>>`. Relic makes this explicit in the type system:

```dart
// Shelf
Stream<List<int>> body;  // Runtime is Uint8List, but type says List<int>

// Relic
Stream<Uint8List> body;  // Type matches runtime, making intent clear
```

This eliminates potential type confusion and makes the API contract explicit.

#### Body Architecture

In Shelf, the content-type header and encoding live separately from the body, which can lead to mismatches. Relic's `Body` class encapsulates everything together:

```dart
class Body {
  final Stream<Uint8List> stream;
  final int? contentLength;
  final BodyType? bodyType;  // Combines mimeType + encoding
}
```

This design:
- Prevents mismatches between declared and actual encoding
- Eliminates the need to parse headers to understand body format
- Provides a single source of truth for content metadata
- Type-safe body creation: `Body.fromString()`, `Body.fromData()`, `Body.fromDataStream()`

#### Path Normalization with LRU Caching

Every incoming path is normalized (resolving `.`, `..`, multiple slashes) and interned using an LRU cache.

Common paths like `/api/users` or `/assets/logo.png` are cached and reused, avoiding repeated parsing and allocation. With 10,000 entries, most production applications will see near-perfect cache hit rates.

#### Trie-based Routing

As mentioned in the routing section, the trie data structure provides O(segments) lookup time regardless of how many routes are registered. This scales much better than linear scanning as your application grows.

**These aren't premature optimizations** - they're foundational design choices that make Relic faster by default without requiring developers to think about performance.

### Built-in WebSocket Support

Unlike Shelf, which requires the separate `shelf_web_socket` package, Relic has WebSocket support built into the core. WebSockets integrate cleanly with the state machine via `ConnectContext`:

```dart
Handler webSocketHandler = (NewContext ctx) {
  return ctx.connect((RelicWebSocket ws) async {
    await for (final event in ws.events) {
      if (event is TextDataReceived) {
        ws.trySendText('Echo: ${event.text}');
      }
    }
  });
};
```

#### Try-Variants for Graceful Error Handling

`RelicWebSocket` provides non-throwing variants of common operations:

```dart
// Instead of throwing when the connection is closed
if (ws.trySendText('Hello')) {
  // Message sent successfully
} else {
  // Connection was closed, handle gracefully
}

// Standard throwing variant also available
ws.sendText('Hello');  // Throws WebSocketConnectionClosed if closed

// Check state explicitly
if (!ws.isClosed) {
  ws.sendText('Hello');
}
```

This makes it easier to write robust WebSocket handlers that gracefully handle connection closures without try-catch blocks.

#### Comparison to Shelf

```dart
// Shelf approach (separate package)
import 'package:shelf_web_socket/shelf_web_socket.dart';

var handler = webSocketHandler((webSocket) {
  webSocket.stream.listen(...);
  webSocket.sink.add(...);
});

// Relic approach (built-in, state machine integration)
Handler handler = (NewContext ctx) {
  return ctx.connect((RelicWebSocket ws) {
    ws.events.listen(...);
    ws.trySendText(...);  // Non-throwing variant
  });
};
```

**Advantages:**
- Built-in to core, no extra dependencies
- Type-safe integration via state machine
- Try-variants for graceful error handling
- Explicit `isClosed` state checking
- Uses standard `package:web_socket` interface

## Migration

If you are inspired to migrate from Shelf to Relic then here is some steps to consider:

TODO: we should elaborate on how to migrate from Shelf to Relic.

## Contributing

We hope to see Relic evolve into a community effort.

### Test, test, test

TODO: This section probably don't belong here. Or we should have a call for contributions where this goes below

We have added a lot of automated tests to ensure we can evolve Relic with safety. If you want to contribute be prepared to add tests to your PR. We aim to not decrease coverage, which currently stand at 92%.

We aspire to follow the Given-When-Then style of tests from BDD (Behavior Driven Development). Please take some time familiarize yourself with the concept before embarking on a contribution.

You can read more in CONTRIBUTING.md in the repo.
