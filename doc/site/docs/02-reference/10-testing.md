---
sidebar_position: 10
---

# Testing

The most faithful test of a Relic app sends it real HTTP requests. Serve the app on a free port, point an HTTP client at it, and close it when the test ends. That covers everything a client sees, from routing to the headers the adapter writes.

When a test needs a `Request` object of its own, for example to call a middleware directly, there is a second way. It runs the handler in a `RelicServer` on an in-process adapter, with no sockets at all.

## Testing against a running server

Serve the app on port `0` and the operating system picks a free port. The `port` of the returned server says which one it got. The test below starts a fresh server for each test in `setUp` and closes it with `addTearDown`.

GITHUB_CODE_BLOCK lang="dart" file="../_example/test/serve_test.dart" doctag="testing-serve" title="Testing a served app"

This needs `package:http` as a dev dependency. `serve` binds to the IPv4 loopback address by default, so the test connects to `127.0.0.1`. The name `localhost` can resolve to the IPv6 address first.

## Testing without sockets

`Request` has no public constructor. A server builds every request from what its adapter received, through a `RequestFactory` that only the server holds. A test that needs a `Request` without opening a socket therefore runs the handler in a `RelicServer` on an adapter of its own.

The file below is such an adapter. Copy it into your `test` directory. It needs nothing beyond `package:relic` and `package:test`.

- `handle` runs a handler in a server and answers one request with it.
- `requestFor` returns the `Request` the server built for a request, for code that takes a `Request` directly.

GITHUB_CODE_BLOCK lang="dart" file="../_example/test/in_process_server.dart" doctag="testing-in-process-server" title="An in-process adapter"

`InProcessAdapter` and `InProcessExchange` extend `Fake` from `package:test`, so they only implement what the server calls for a plain request and response. A handler that hijacks the connection or upgrades to a WebSocket needs a real server.

Here it tests a middleware, first through the server and then directly with a request from `requestFor`:

GITHUB_CODE_BLOCK lang="dart" file="../_example/test/in_process_server_test.dart" doctag="testing-in-process-test" title="Testing a middleware in process"

`requestFor` hands back the request after the server has answered it. That suits code that reads the method, URL and headers and returns a `Response`. `copyWith` makes variations of it with another URL, headers or body. A different method needs another call to `requestFor`.
