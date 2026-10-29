---
sidebar_position: 12
---

# Serving

`app.serve()` is the last line of most programs on this site. It binds a socket and hands every connection to the app, and it is where the choices about the network live: which address and port, how many isolates, and which adapter speaks HTTP. This page takes them in turn.

## Address, port and close

`serve` listens on the IPv4 loopback address and port 8080 unless told otherwise. A server that other machines should reach binds `InternetAddress.anyIPv4`, and port `0` asks the operating system for a free port. The returned `RelicServer` tells which port it got, and `app.close()` stops it:

GITHUB_CODE_BLOCK lang="dart" file="../_example/serving/isolates.dart" doctag="serving-serve" title="Binding, and closing on Ctrl-C"

A close is graceful by default. The server stops accepting, lets the requests in flight finish, tells every WebSocket it is going away and then returns. `close(force: true)` drops every connection at once.

## Isolates

A Dart isolate runs one thing at a time. A handler that does real work holds the isolate for as long as that work takes, and every other request waits. `noOfIsolates` starts that many isolates, each with the whole app and its own socket on the same port, and the operating system spreads the connections over them.

The program on this page counts the requests each isolate has served:

GITHUB_CODE_BLOCK lang="dart" file="../_example/serving/isolates.dart" doctag="serving-isolate-state" title="A counter that lives in each isolate"

Started with four isolates, twelve requests sent at once land like this:

```bash
dart run serving/isolates.dart 4
```

```text
Listening on port 8080 with 4 isolate(s)
```

```bash
seq 12 | xargs -P 12 -I{} curl -s http://localhost:8080/count | sort
```

```text
isolate 14321552 served 1
isolate 14321552 served 2
isolate 14321552 served 3
isolate 186927541 served 1
isolate 186927541 served 2
isolate 186927541 served 3
isolate 613516264 served 1
isolate 613516264 served 2
isolate 818564193 served 1
isolate 818564193 served 2
isolate 818564193 served 3
isolate 818564193 served 4
```

Which isolate takes a connection is up to the operating system, so the split differs from run to run. What does not differ is that `served` counts separately in each isolate. A global variable, a cache, a database connection: each isolate has its own. State the whole server must share lives outside the process, in a database or a cache server, or in one isolate the others talk to.

The isolates are built from the app in `main`, so everything the app holds has to be sendable to another isolate. Named functions, closures over sendable values and plain data are. An open socket, a database connection or a `ReceivePort` is not, and `serve` fails when a route holds one. Open such things inside the handler, or in a factory the handler calls, so each isolate opens its own.

## Adapters

An adapter is the piece that speaks HTTP. It accepts connections, parses requests into `Request` objects, hands them to the app, and writes the responses back. `serve` is a shortcut for `run` with the adapter from `relic_io`, which is built on `dart:io`. `run` takes a function that makes the adapter, and calls it once per isolate:

GITHUB_CODE_BLOCK lang="dart" file="../_example/serving/adapter.dart" doctag="serving-run" title="run with an explicit adapter"

`serve` passes its `address`, `port` and `securityContext` on to `IOAdapter.bind`, so the shortcut covers HTTPS too. `run` is for an adapter with no shortcut of its own, and for a program that wants to make the adapter itself.

## relic_native

`relic_native` is a second adapter, with the HTTP parsing, the keep-alive handling and the timeouts in native code. An acceptor thread hands each connection to the isolate with the fewest, and from there its bytes are read and written on that isolate's thread, between the isolate's Dart work. A handler sees the same `Request` either way, and the whole test suite of Relic runs against both adapters.

It is a separate package, so add it next to `relic`:

```bash
dart pub add relic_native
```

The package ships a prebuilt library for Linux, macOS and Windows on x64 and arm64. Building it from source needs Zig, which the package's README describes. On another platform the package builds nothing and `serveNative` throws, so use `relic_io` there.

`serveNative` takes the place of `serve`:

GITHUB_CODE_BLOCK lang="dart" file="../_example/serving/native.dart" doctag="serving-native" title="The same app on the native adapter"

```bash
dart run serving/native.dart 4
```

```text
Listening on port 8080 with 4 isolate(s)
```

```bash
curl -i http://localhost:8080/
```

```text
HTTP/1.1 200 OK
content-type: text/plain; charset=utf-8
date: Mon, 26 Oct 2026 11:52:49 GMT
content-length: 6

Hello
```

The response is the one `relic_io` sends, header for header. The `options` argument, a `NativeOptions`, sets the limits and timeouts: the listen backlog, a cap on open connections, the idle, header, body and write timeouts, the size of a body that is read before the handler runs, and the largest WebSocket message. Their defaults suit a server behind a proxy.

### What the native adapter does not do

- It speaks HTTP/1.0 and HTTP/1.1 only, with `Content-Length` and chunked bodies both ways. There is no HTTP/2 or HTTP/3.
- It does not terminate TLS. Put a proxy in front for HTTPS, or stay with `relic_io`, whose `serve` takes a `SecurityContext`.
- A request head is at most 16 KiB with at most 128 header fields.

### Choosing

`relic_io` is the default for a reason. It runs wherever Dart runs, it has no native library in the process, and it terminates TLS itself. Stay with it until you have measured the server, not the database or the handler, as the limit. When that happens, `relic_native` answers several times the requests per second of `relic_io` on one isolate on a trivial route, with a lower tail latency under load, because a busy isolate no longer stalls the parsing of the next request. Both adapters support hot reload, hijacking and WebSockets, so a program can switch between them by changing the one line that serves.

## Examples & further reading

### Examples

- **[Isolates example](https://github.com/serverpod/relic/blob/main/packages/examples/serving/isolates.dart)** - The counter and the close on Ctrl-C.
- **[Adapter example](https://github.com/serverpod/relic/blob/main/packages/examples/serving/adapter.dart)** - `run` with an explicit adapter.
- **[Native example](https://github.com/serverpod/relic/blob/main/packages/examples/serving/native.dart)** - The same app on `relic_native`.

### API documentation

- **[RelicApp.run](https://pub.dev/documentation/relic_core/latest/relic_core/RelicApp/run.html)**
- **[RelicServer](https://pub.dev/documentation/relic_core/latest/relic_core/RelicServer-class.html)**
- **[RelicAppIOServeEx.serve](https://pub.dev/documentation/relic_io/latest/relic_io/RelicAppIOServeEx/serve.html)**
- **[relic_native](https://pub.dev/packages/relic_native)**
