---
sidebar_position: 1
---

# Handlers

Handlers are functions that process incoming requests in Relic applications. Think of them as the core logic that decides what to do when someone visits your web server.

What makes Relic handlers special is their flexibility. Unlike traditional web frameworks where handlers only return HTTP responses, Relic handlers can:

- Send regular HTTP responses (like web pages or API data)
- Upgrade connections to WebSockets for real-time communication
- Take direct control of the network connection for custom protocols

This is why Relic handlers work with "context" objects instead of just taking a request and returning a response. The context gives you multiple ways to handle the connection based on what your application needs.

## Handler types

In Relic, there are four main handler types for different scenarios:

### 1. Handler (foundational)

The `Handler` is the foundational handler type that serves as the core building block for all Relic applications. It provides the most flexibility by accepting any incoming request context and allowing you to return various types of handled contexts, making it suitable for any kind of request processing logic.

```dart
typedef Handler = FutureOr<HandledContext> Function(NewContext ctx);
```

- `NewContext ctx` is the incoming request context.
- `FutureOr<HandledContext>` is a response context, hijacked connection, or WebSocket connection.

**Example:**

```dart
import 'package:relic/relic.dart';

Handler helloHandler(NewContext ctx) {
  return ctx.respond(Response.ok(
    body: Body.fromString('Hello from Relic!'),
  ));
};
```

### 2. Responder

A `Responder` is a simplified function type that provides a more straightforward approach to request handling by directly transforming an HTTP request into an HTTP response. It abstracts away the context handling, making it perfect for simple request-response scenarios and can easily be converted into a full `Handler` using the `respondWith` helper function.

```dart
typedef Responder = FutureOr<Response> Function(Request request);
```

- `Request request` is the incoming HTTP request.
- `FutureOr<Response>` is the HTTP response to send.

**Example:**

```dart
import 'package:relic/relic.dart';

final simpleResponderHandler = respondWith(
  (Request request) {
    return Response.ok(
      body: Body.fromString('Hello, ${request.url.path}!'),
    );
  },
);
```

### 3. ResponseHandler

A `ResponseHandler` is a specialized handler designed specifically for scenarios where you need to generate standard HTTP responses. It ensures type safety by guaranteeing that the context can produce a response and that you'll always return a response context, making it ideal for typical web API endpoints and page serving.

```dart
typedef ResponseHandler = FutureOr<ResponseContext> Function(RespondableContext ctx);
```

- `RespondableContext ctx` is a context that guarantees you can call `respond()`.
- `FutureOr<ResponseContext>` is a response context containing the HTTP response.

**Example:**

```dart
import 'package:relic/relic.dart';

ResponseContext apiHandler(RespondableContext context) {
  return context.respond(
    Response.ok(
      headers: Headers.build(
        (final MutableHeaders mh) => mh.xPoweredBy = 'Relic',
      ),
      body: Body.fromString('{"status": "success"}'),
    ),
  );
}
```

### 4. HijackHandler

A `HijackHandler` is a powerful handler type that enables you to take complete control of the underlying connection for advanced use cases like WebSocket upgrades or Server-Sent Events (SSE). It bypasses the normal HTTP request-response cycle, allowing for bidirectional communication and real-time data streaming directly over the raw connection.

```dart
typedef HijackHandler = FutureOr<HijackContext> Function(HijackableContext ctx);
```

- `HijackableContext ctx` is a context that allows hijacking the connection.
- `FutureOr<HijackContext>` is a hijacked connection context.

**Example:**

```dart
import 'dart:async';
import 'dart:convert';
import 'package:relic/relic.dart';
import 'package:stream_channel/stream_channel.dart';

HijackContext sseHandler(HijackableContext ctx) {
  return ctx.hijack((StreamChannel<List<int>> channel) async {
    // Send Server-Sent Events
    channel.sink.add(utf8.encode('data: Connected\n\n'));

    // Send periodic updates
    final timer = Timer.periodic(Duration(seconds: 1), (_) {
      channel.sink.add(utf8.encode('data: ${DateTime.now()}\n\n'));
    });

    // Wait for client disconnect, then cleanup
    await channel.sink.done;
    timer.cancel();
  });
}
```

## How to define handlers

### Synchronous handlers

For simple, fast operations:

```dart
ResponseContext syncHandler(NewContext ctx) {
  return ctx.respond(Response.ok(
    body: Body.fromString('Fast response'),
  ));
}
```

### Asynchronous handlers

For operations that need to wait (database calls, file I/O, etc.):

```dart
Future<ResponseContext> asyncHandler(NewContext ctx) async {
  final data = await Future.delayed(
    const Duration(seconds: 1),
    () => 'Hello from Relic!',
  );

  return ctx.respond(Response.ok(
    body: Body.fromString(data),
  ));
}
```

### Using context data

Handlers receive context information about the request:

```dart
ResponseContext contextHandler(NewContext ctx) {
  // Access the request
  final request = ctx.request;

  // HTTP method
  final method = request.method; // 'GET', 'POST', etc.

  // Request URL
  final url = request.url;

  // Headers
  final userAgent = request.headers.userAgent;

  return ctx.respond(
    Response.ok(
      body: Body.fromString(
        'Method: $method, Path: ${url.path} User-Agent: $userAgent',
      ),
    ),
  );
}
```

### Handling WebSocket connections

For real-time bidirectional communication, you can upgrade connections to WebSockets using `ctx.connect()`:

```dart
import 'dart:async';
import 'dart:developer';
import 'package:relic/relic.dart';

ConnectContext webSocketHandler(NewContext ctx) {
  return ctx.connect((RelicWebSocket channel) async {
    // Send initial connection message
    channel.sendText('data: Connected\n\n');

    // Send periodic updates
    final timer = Timer.periodic(Duration(seconds: 1), (_) {
      channel.sendText('data: ${DateTime.now()}\n\n');
    });

    // Listen to incoming events and cleanup on disconnect
    channel.events.listen(
      (event) => log('event: $event'),
      onDone: () => timer.cancel(),
    );
  });
}
```
