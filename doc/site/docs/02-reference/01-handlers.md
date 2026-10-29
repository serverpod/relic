---
sidebar_position: 1
---

# Handlers

Everything a Relic server does for a request, it does in a handler. A handler is a function that receives the request and returns what should happen next. Its type says exactly that:

```dart
typedef Handler = FutureOr<Result> Function(Request req);
```

The parameter is the incoming `Request`. The return type has two parts. `FutureOr` lets a handler answer right away, or return a `Future` when it has to wait for something first. `Result` is what the handler wants done with the connection, and it comes in three kinds. A `Response` answers the request in the ordinary way. A `WebSocketUpgrade` turns the connection into a WebSocket. A `Hijack` hands the raw connection to the handler. This page takes them in that order.

The examples all come from one program, which registers them like this:

GITHUB_CODE_BLOCK lang="dart" doctag="handler-routes" file="../_example/basic/handler.dart" title="The routes of the handler example"

## Answering with a response

The simplest handler builds a response and returns it:

GITHUB_CODE_BLOCK lang="dart" doctag="handler-foundational" file="../_example/basic/handler.dart" title="A handler that answers at once"

```bash
curl -i http://localhost:8080/hello
```

```text
HTTP/1.1 200 OK
content-type: text/plain; charset=utf-8
date: Fri, 23 Oct 2026 11:51:17 GMT
content-length: 17

Hello from Relic!
```

A handler that has to wait, for a database, a file or another service, is an `async` function that returns a `Future<Response>`. This one waits a quarter of a second before it answers:

GITHUB_CODE_BLOCK lang="dart" doctag="handler-async" file="../_example/basic/handler.dart" title="A handler that waits"

Relic awaits the future before it sends anything. Timing the request with curl's `-w` option shows the wait:

```bash
curl -s -o /dev/null -w '%{time_total}s\n' http://localhost:8080/async
```

```text
0.252923s
```

Most handlers need to know something about the request. The `Request` carries the method, the URL, the headers and the body, and this handler reads three of them:

GITHUB_CODE_BLOCK lang="dart" doctag="handler-context" file="../_example/basic/handler.dart" title="A handler that reads the request"

```bash
curl http://localhost:8080/context
```

```text
Method: get, Path: /context, User-Agent: curl/8.7.1
```

The method is a value of the `Method` enum, and `name` gives its Dart name, `get`. The [Requests](./04-requests.md) page covers everything a request carries, and the [Responses](./05-responses.md) page what you can send back.

## Upgrading to a WebSocket

HTTP is a conversation in turns. The client asks, and the server answers. A WebSocket keeps the connection open, so that either side can send a message whenever it has one. The client starts with an ordinary GET request that asks for an upgrade, and a handler accepts by returning a `WebSocketUpgrade`:

GITHUB_CODE_BLOCK lang="dart" doctag="handler-websocket-echo" file="../_example/basic/handler.dart" title="A WebSocket that echoes"

The function you give `WebSocketUpgrade` runs once the connection has been upgraded. It receives a `RelicWebSocket`, which sends with `sendText` and delivers what the client sends as a stream of `events`. This handler greets the client, then echoes every text message, and its loop ends when the client closes the connection. The event types, such as `TextDataReceived`, come from `package:web_socket`, so add that package as a dependency and import it next to `package:relic`.

curl does not speak WebSocket, so here is a small client written with the same package. It waits for the greeting, sends a message, and closes after the echo:

GITHUB_CODE_BLOCK lang="dart" doctag="handler-websocket-client" file="../_example/basic/websocket_client.dart" title="A WebSocket client"

Running it against the server prints the conversation, with `<` for what arrived and `>` for what it sent:

```text
< Welcome to Relic WebSocket!
> hello
< Echo: hello
```

A request to `/ws` that does not ask for an upgrade, such as a plain `curl`, gets a 400:

```text
HTTP/1.1 400 Bad Request
content-type: text/plain; charset=utf-8
date: Fri, 23 Oct 2026 11:51:18 GMT
content-length: 31

Not a WebSocket upgrade request
```

Relic also checks where an upgrade comes from. A browser names the page that opened the socket in the `Origin` header, and Relic refuses an upgrade from a page on another host with 403. Browsers attach cookies to WebSocket requests and do not apply CORS to them, so without this check any web page could open a socket on a visitor's session. Set `allowAnyOrigin: true` on the `WebSocketUpgrade` only for an endpoint meant to be opened by other sites, and that does not authenticate with cookies.

## Taking over the connection

A `Hijack` is the most direct of the three results. Relic hands the handler the raw connection, as a channel of bytes, and steps aside. It writes nothing itself, not even a status line. That suits a protocol of your own, or a stream of events that does not end. This handler sends Server-Sent Events, a format browsers read with `EventSource`:

GITHUB_CODE_BLOCK lang="dart" doctag="handler-hijack-sse" file="../_example/basic/handler.dart" title="Server-Sent Events over a hijacked connection"

The handler writes the status line, the headers and the blank line that ends them, then an event every second. Each event is a `data:` line followed by an empty line. With `-N`, curl prints the bytes as they arrive:

```bash
curl -i -N http://localhost:8080/sse
```

```text
HTTP/1.1 200 OK
Content-Type: text/event-stream
Cache-Control: no-cache
Connection: close

data: Connected

data: 2026-10-23 13:51:19.855480

data: 2026-10-23 13:51:20.855145
```

Notice the capitalized header names. Relic writes its own headers in lowercase, but these bytes came straight from the handler.

The example registers the handler for HEAD as well as GET, and writes only the head for a HEAD request. Relic answers HEAD for a GET route by itself, sending the GET response without its body. It cannot do that once the handler writes its own bytes, so a GET route that returns a `Hijack` answers HEAD with 405, unless the path has a HEAD route of its own.

A hijack also needs the request body out of the way. When the client may send the body chunked, read it to its end before returning a `Hijack`. An adapter cannot hand back the raw bytes of a body it has already decoded, so it refuses the hijack, the callback never runs, and the client gets 500.

A `Response` whose body comes from `Body.fromDataStream` also streams, and lets Relic write the head. The dart:io adapter buffers a streamed body, though, so small pieces like these events can wait until more data follows or the stream ends. A hijacked channel writes straight to the socket, and each event above arrived the moment the handler wrote it, which is why this example hijacks.

## Examples & further reading

### Examples

- **[Handler example](https://github.com/serverpod/relic/blob/main/packages/examples/basic/handler.dart)** - The program behind this page.
- **[WebSocket client](https://github.com/serverpod/relic/blob/main/packages/examples/basic/websocket_client.dart)** - The client that talks to its WebSocket handler.

### API documentation

- [Handler typedef](https://pub.dev/documentation/relic/latest/relic/Handler.html) - Core handler function signature.
- [Result class](https://pub.dev/documentation/relic/latest/relic/Result-class.html) - Base class for handler return values.
- [Response class](https://pub.dev/documentation/relic/latest/relic/Response-class.html) - HTTP response result.
- [WebSocketUpgrade class](https://pub.dev/documentation/relic/latest/relic/WebSocketUpgrade-class.html) - WebSocket upgrade result.
- [Hijack class](https://pub.dev/documentation/relic/latest/relic/Hijack-class.html) - Connection hijacking result.
