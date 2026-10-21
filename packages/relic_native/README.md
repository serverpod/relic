# relic_native

A [Relic](https://pub.dev/packages/relic) adapter backed by a Zig HTTP
server ([zio](https://github.com/lalinsky/zio) and `std.http.Server`) that
each isolate drives from its own thread.

An acceptor thread hands each connection to the isolate with the fewest.
From there the parsing, the keep-alive handling and the timeouts run in
native code between the isolate's Dart work, and a request reaches the
handler as plain Dart data. The adapter is opt-in: `app.serve()` stays on
`relic_io`, and this package is used through `serveNative`.

```dart
import 'package:relic_core/relic_core.dart';
import 'package:relic_native/relic_native.dart';

Future<void> main() async {
  final app = RelicApp()..get('/', (final req) => Response.ok());
  await app.serveNative(port: 8080, noOfIsolates: 4);
}
```

## Platforms

Linux (x64, arm64), macOS (arm64, x64) and Windows (x64, arm64). On
another platform the package builds no native library, and
`NativeAdapter.bind` throws. Use `relic_io` there.

## Building from source

The published package ships prebuilt libraries. A source checkout compiles
with Zig through the build hook. The `zig` on `PATH` must be the version in
`build.zig.zon`, or [anyzig](https://github.com/marler8997/anyzig), which
picks it from that file.

## Isolates

Each isolate runs its own reactor on its own thread: the sockets, the
parsing and the writes of the connections it was handed happen between
its Dart work, in ticks the adapter drives from the event loop. One
acceptor thread per server hands each new connection to the isolate
with the fewest. `noOfIsolates` is the one knob, and a trivial route
scales with it up to the machine's cores.

## Choosing between relic_io and relic_native

`relic_io` is the default. `app.serve()` uses it and the `relic` package
does not depend on `relic_native`. Both run the same handlers, middleware
and router, and both pass the same conformance suite. The differences:

- Throughput and tail latency. On a plaintext route the native adapter
  answers several times the requests per second of `relic_io` on one
  isolate, and its p99 under load is lower, since parsing and keep-alive
  run on native threads while the isolate is busy. The numbers are in
  `doc/design/relic_native/NOTES.md`.
- TLS. `relic_io` terminates TLS itself. `relic_native` does not, so put
  a proxy in front or stay with `relic_io`.
- Platforms. `relic_io` runs wherever Dart does. `relic_native` runs on
  Linux, macOS and Windows.
- Dependencies. `relic_io` is pure Dart. `relic_native` ships prebuilt
  libraries and needs Zig only for a source checkout.

Stay with `relic_io` unless you have measured the dart:io adapter as the
bottleneck and run behind a proxy. `relic_native` is newer code with a
native library in the process, and the gain only matters once the server
is the limit.

## Limits

HTTP/1.0 and HTTP/1.1 only, with `Content-Length` and chunked bodies
both ways. No HTTP/2 or HTTP/3. No TLS in process, terminate it in
front. A handler can hijack the connection as a raw byte channel, and a
WebSocket upgrade is framed by the native side, so `capabilities.hijack`
and `capabilities.webSocket` are both true. A WebSocket message is at
most `maxWebSocketMessage` bytes, 16 MiB unless `bind` is told
otherwise. A request head is at most 16 KiB with at most 128 fields, and
a body over `maxInlineBody` streams to the handler instead of being read
first.
