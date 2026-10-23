---
sidebar_position: 1
---

# Handlers

Handlers are functions that process incoming requests in Relic applications. Think of them as the core logic that decides what to do when someone visits your web server.

Most handlers answer with an HTTP response, such as a web page or some JSON. A Relic handler can also do two other things:

- Upgrade the connection to a WebSocket, for messages in both directions.
- Take over the network connection, for a protocol of its own.

Relic handlers take a `Request` and return a `Result`, which can be a `Response`, `Hijack` (for connection hijacking), or `WebSocketUpgrade` (for WebSocket connections).

The `Handler` is the foundational handler type that serves as the core building block for all Relic applications. It provides the most flexibility by accepting any incoming request and allowing you to return various types of results, making it suitable for any kind of request processing logic.

```dart
typedef Handler = FutureOr<Result> Function(Request req);
```

- `Request req` is the incoming HTTP request.
- `FutureOr<Result>` is a result that can be a `Response`, `Hijack`, or `WebSocketUpgrade`.

**Example:**

GITHUB_CODE_BLOCK lang="dart" doctag="handler-foundational" file="../_example/basic/handler.dart" title="Foundational handler example"

## How to define handlers

### Synchronous handlers

For simple, fast operations:

GITHUB_CODE_BLOCK lang="dart" doctag="handler-sync" file="../_example/basic/handler.dart" title="Synchronous handler"

### Asynchronous handlers

For operations that need to wait (database calls, file I/O, etc.):

GITHUB_CODE_BLOCK lang="dart" doctag="handler-async" file="../_example/basic/handler.dart" title="Asynchronous handler"

### Using request data

Handlers receive request information including the method, URL and headers:

GITHUB_CODE_BLOCK lang="dart" doctag="handler-context" file="../_example/basic/handler.dart" title="Using request data"

### Handling WebSocket connections

For real-time bidirectional communication, you can upgrade connections to WebSockets by returning a `WebSocketUpgrade`:

GITHUB_CODE_BLOCK lang="dart" doctag="context-websocket-echo" file="../_example/context/context.dart" title="WebSocket example"

The event types, such as `TextDataReceived` and `CloseReceived`, come from `package:web_socket`. Add it as a dependency and import it next to `package:relic`.

A request that is not a valid opening handshake gets 400. An upgrade from a page on another origin gets 403, unless the `WebSocketUpgrade` sets `allowAnyOrigin: true`. Set that only for an endpoint meant to be opened by other sites, and that does not authenticate with cookies. An adapter that supports neither WebSockets nor hijacking answers 501.

### Hijacking connections

For advanced use cases like Server-Sent Events (SSE) or custom protocols, you can hijack the connection:

GITHUB_CODE_BLOCK lang="dart" doctag="handler-hijack-sse" file="../_example/basic/handler.dart" title="Connection hijacking example"

The handler writes everything on the channel itself, starting with the status line and headers. Read the request body to its end before returning a `Hijack` when the client may send it chunked. An adapter cannot hand back the raw bytes of a body it decoded, so it refuses the hijack. The callback then never runs, and the client gets 500.

## Examples & further reading

### Examples

- **[Handler example](https://github.com/serverpod/relic/blob/main/packages/examples/basic/handler.dart)** - The complete working example from this guide.

### API documentation

- [Handler typedef](https://pub.dev/documentation/relic/latest/relic/Handler.html) - Core handler function signature.
- [Result class](https://pub.dev/documentation/relic/latest/relic/Result-class.html) - Base class for handler return values.
- [Response class](https://pub.dev/documentation/relic/latest/relic/Response-class.html) - HTTP response result.
- [WebSocketUpgrade class](https://pub.dev/documentation/relic/latest/relic/WebSocketUpgrade-class.html) - WebSocket upgrade result.
- [Hijack class](https://pub.dev/documentation/relic/latest/relic/Hijack-class.html) - Connection hijacking result.
