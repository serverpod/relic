---
sidebar_position: 1
---

# Handlers

Handlers are functions that process incoming requests in Relic applications. Think of them as the core logic that decides what to do when someone visits your web server.

What makes Relic handlers special is their flexibility. Unlike traditional web frameworks where handlers only return HTTP responses, Relic handlers can:

- Send regular HTTP responses (like web pages or API data)
- Upgrade connections to WebSockets for real-time communication
- Take direct control of the network connection for custom protocols

Relic handlers take a `Request` and return a `Result`, which can be a `Response`, `Hijack` (for connection hijacking), or `WebSocketUpgrade` (for WebSocket connections).

## Handler types

In Relic, there are two main handler types for different scenarios:

### 1. Handler (foundational)

The `Handler` is the foundational handler type that serves as the core building block for all Relic applications. It provides the most flexibility by accepting any incoming request and allowing you to return various types of results, making it suitable for any kind of request processing logic.

```dart
typedef Handler = FutureOr<Result> Function(Request req);
```

- `Request req` is the incoming HTTP request.
- `FutureOr<Result>` is a result that can be a `Response`, `Hijack`, or `WebSocketUpgrade`.

**Example:**

GITHUB_CODE_BLOCK lang="dart" doctag="handler-foundational" [src](https://raw.githubusercontent.com/serverpod/relic/main/example/basic/handler_example.dart) title="Foundational Handler example"

### 2. Responder

A `Responder` is a simplified function type that provides a more straightforward approach to request handling by directly transforming an HTTP request into an HTTP response. It can easily be converted into a full `Handler` using the `respondWith` helper function.

```dart
typedef Responder = FutureOr<Response> Function(Request request);
```

- `Request request` is the incoming HTTP request.
- `FutureOr<Response>` is the HTTP response to send.

**Example:**

GITHUB_CODE_BLOCK lang="dart" doctag="handler-responder" [src](https://raw.githubusercontent.com/serverpod/relic/main/example/basic/handler_example.dart) title="Responder example"

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

### Hijacking connections

For advanced use cases like Server-Sent Events (SSE) or custom protocols, you can hijack the connection:

GITHUB_CODE_BLOCK lang="dart" doctag="handler-hijack-sse" [src](https://raw.githubusercontent.com/serverpod/relic/main/example/basic/handler_example.dart) title="Connection hijacking example"

### Handling WebSocket connections

For real-time bidirectional communication, you can upgrade connections to WebSockets by returning a `WebSocketUpgrade`:

GITHUB_CODE_BLOCK lang="dart" doctag="context-websocket-echo" [src](https://raw.githubusercontent.com/serverpod/relic/main/example/context/context_example.dart) title="WebSocket example"
