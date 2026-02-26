---
name: relic-websockets
description: Handle WebSocket connections and hijack connections for SSE or custom protocols in Relic. Use when implementing real-time communication, WebSocket endpoints, or server-sent events.
---

# Relic WebSockets & Connection Hijacking

Relic handlers return a `Result`, which can be a `Response`, `WebSocketUpgrade`, or `Hijack`. WebSockets and hijacking are built-in -- no extra packages needed.

## WebSocket connections

Return a `WebSocketUpgrade` to upgrade an HTTP connection to a WebSocket:

```dart
app.get('/ws', (Request req) {
  return WebSocketUpgrade((webSocket) async {
    webSocket.sendText('Welcome!');

    await for (final event in webSocket.events) {
      switch (event) {
        case TextDataReceived(text: final message):
          webSocket.sendText('Echo: $message');
        case CloseReceived():
          break;
        default:
          break;
      }
    }
  });
});
```

### Sending data

```dart
webSocket.sendText('Hello!');      // throws on failure
webSocket.trySendText('Hello!');   // silent on failure
```

### Event types

Listen on `webSocket.events` and pattern-match:

- `TextDataReceived(text: final message)` -- text frame received
- `CloseReceived()` -- connection closed by client

### Simple listener pattern

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

## Connection hijacking

Return a `Hijack` to take direct control of the underlying TCP connection. Useful for Server-Sent Events (SSE) or custom protocols:

### SSE example

```dart
app.get('/sse', (Request req) {
  return Hijack((channel) async {
    channel.sink.add(utf8.encode('data: Connected\n\n'));

    final timer = Timer.periodic(
      Duration(seconds: 1),
      (_) => channel.sink.add(
        utf8.encode('data: ${DateTime.now()}\n\n'),
      ),
    );

    await channel.sink.done;
    timer.cancel();
  });
});
```

### Custom protocol

```dart
app.get('/custom', (Request req) {
  return Hijack((channel) {
    const response =
        'HTTP/1.1 200 OK\r\n'
        'Content-Type: text/plain\r\n'
        'Connection: close\r\n'
        '\r\n'
        'Custom protocol response!';

    channel.sink.add(utf8.encode(response));
    channel.sink.close();
  });
});
```

## Complete server example

```dart
import 'dart:async';
import 'dart:convert';

import 'package:relic/relic.dart';

Future<void> main() async {
  final app = RelicApp()
    ..get('/ws', (req) {
      return WebSocketUpgrade((ws) async {
        ws.sendText('Welcome to Relic WebSocket!');
        await for (final event in ws.events) {
          switch (event) {
            case TextDataReceived(text: final message):
              ws.sendText('Echo: $message');
            case CloseReceived():
              break;
            default:
              break;
          }
        }
      });
    })
    ..get('/sse', (req) {
      return Hijack((channel) async {
        channel.sink.add(utf8.encode('data: Connected\n\n'));
        final timer = Timer.periodic(
          Duration(seconds: 1),
          (_) => channel.sink.add(utf8.encode('data: tick\n\n')),
        );
        await channel.sink.done;
        timer.cancel();
      });
    });

  await app.serve();
}
```
