---
sidebar_position: 1
---

# Handlers

Handlers are functions that process incoming requests in Relic applications. Think of them as the core logic that decides what to do when someone visits your web server.

What makes Relic handlers special is their flexibility. Unlike traditional web frameworks, where handlers only return HTTP responses, Relic handlers can:

- Send regular HTTP responses (like web pages or API data).
- Upgrade connections to WebSockets for real-time communication.
- Take direct control of the network connection for custom protocols.

Relic handlers take a `Request` and return a `Result`, which can be a `Response`, `Hijack` (for connection hijacking), or `WebSocketUpgrade` (for WebSocket connections).

The `Handler` is the foundational handler type that serves as the core building block for all Relic applications. It provides the most flexibility by accepting any incoming request and allowing you to return various types of results, making it suitable for any kind of request processing logic.

```dart
typedef Handler = FutureOr<Result> Function(Request req);
```

- `Request req` is the incoming HTTP request.
- `FutureOr<Result>` is a result that can be a `Response`, `Hijack`, or `WebSocketUpgrade`.

**Example:**

GITHUB_CODE_BLOCK lang="dart" doctag="handler-foundational" [src](https://raw.githubusercontent.com/serverpod/relic/main/example/basic/handler_example.dart) title="Foundational handler example"

## How to define handlers

### Synchronous handlers

For simple, fast operations:

GITHUB_CODE_BLOCK lang="dart" doctag="handler-sync" [src](https://raw.githubusercontent.com/serverpod/relic/main/example/basic/handler_example.dart) title="Synchronous handler"

### Asynchronous handlers

For operations that need to wait (database calls, file I/O, etc.):

GITHUB_CODE_BLOCK lang="dart" doctag="handler-async" [src](https://raw.githubusercontent.com/serverpod/relic/main/example/basic/handler_example.dart) title="Asynchronous handler"

### Using request data

Handlers receive request information including method, URL, headers, and query parameters:

GITHUB_CODE_BLOCK lang="dart" doctag="handler-context" [src](https://raw.githubusercontent.com/serverpod/relic/main/example/basic/handler_example.dart) title="Using request data"

### Handling WebSocket connections

For real-time bidirectional communication, you can upgrade connections to WebSockets by returning a `WebSocketUpgrade`:

GITHUB_CODE_BLOCK lang="dart" doctag="context-websocket-echo" [src](https://raw.githubusercontent.com/serverpod/relic/main/example/context/context_example.dart) title="WebSocket example"

### Hijacking connections

For advanced use cases like Server-Sent Events (SSE) or custom protocols, you can hijack the connection:

GITHUB_CODE_BLOCK lang="dart" doctag="handler-hijack-sse" [src](https://raw.githubusercontent.com/serverpod/relic/main/example/basic/handler_example.dart) title="Connection hijacking example"

## Examples & further reading

### Examples

- **[Handler example](https://github.com/serverpod/relic/blob/main/example/basic/handler_example.dart)** - The complete working example from this guide.

### API documentation

- [Handler typedef](https://pub.dev/documentation/relic/latest/relic/Handler.html) - Core handler function signature.
- [Result class](https://pub.dev/documentation/relic/latest/relic/Result.html) - Base class for handler return values.
- [Response class](https://pub.dev/documentation/relic/latest/relic/Response.html) - HTTP response result.
- [WebSocketUpgrade class](https://pub.dev/documentation/relic/latest/relic/WebSocketUpgrade.html) - WebSocket upgrade result.
- [Hijack class](https://pub.dev/documentation/relic/latest/relic/Hijack.html) - Connection hijacking result.
