---
sidebar_position: 8
---

# Middleware

Suppose you want to know how long each request takes. You could start a `Stopwatch` at the top of every handler and print the elapsed time at the bottom, but by the third handler you would start to wonder whether there is a better way. There is. A handler is just a function from a `Request` to a `Result`, so you can write a function that takes a handler and returns a new one. The new handler starts a stopwatch, calls the original, and prints the time:

GITHUB_CODE_BLOCK lang="dart" file="../_example/middleware/timing.dart" doctag="middleware-timed" title="A timing wrapper"

A function of this shape, from one handler to another, is what Relic calls middleware:

```dart
typedef Middleware = Handler Function(Handler next);
```

You could wrap each handler by hand, writing `timed(hello)` where you register it. Instead, give the wrapper to the router with `use`, and it wraps every route at or below the path you name:

GITHUB_CODE_BLOCK lang="dart" file="../_example/middleware/timing.dart" doctag="middleware-timed-use" title="Timing every route"

Run the program and request `/hello` three times. The server prints one line for each request:

```text
GET /hello: 6687 us
GET /hello: 62 us
GET /hello: 53 us
```

The first request is slow because the Dart VM compiles the code the first time it runs. After that, the handler and the middleware around it take about 60 microseconds.

## Before, instead and after

A middleware can do work before it calls `next`, as `timed` starts its stopwatch, and after `next` returns, as `timed` prints the time. It can also decide not to call `next` at all. This middleware checks an API key, and when the key is wrong it answers 401 itself, so the handler never runs:

GITHUB_CODE_BLOCK lang="dart" file="../_example/middleware/auth.dart" doctag="middleware-auth-function" title="An API key check"

Like `timed`, it is a plain function from a handler to a handler, so you give `use` the function itself, without calling it:

GITHUB_CODE_BLOCK lang="dart" file="../_example/middleware/auth.dart" doctag="middleware-auth-function-use" title="Protecting one route"

A request for `/protected` without the key gets the middleware's answer:

```bash
curl -i http://localhost:8080/protected
```

```text
HTTP/1.1 401 Unauthorized
content-type: text/plain; charset=utf-8
date: Fri, 23 Oct 2026 11:40:22 GMT
content-length: 16

Invalid API key
```

A request with the key gets through to the handler:

```bash
curl -i -H 'X-API-Key: secret123' http://localhost:8080/protected
```

```text
HTTP/1.1 200 OK
content-type: text/plain; charset=utf-8
date: Fri, 23 Oct 2026 11:40:22 GMT
content-length: 19

This is protected!
```

After `next` returns, a middleware can also change the result before passing it on. The CORS middleware near the end of this page adds a header to every response that way.

A middleware can even pass `next` a different request from the one it received, made with `request.copyWith`. By then the routing has already happened, though. A new URL does not send the request to another route, and `pathParameters` still describe the original match. To route a request again, use `request.forwardTo`, described under [Forwarding requests](./04-requests.md#forwarding-requests). To hand data to the handler, such as the user an auth middleware found, set a [context property](./02-context.md) on the request instead.

## Middleware with settings

The key in `requireApiKey` is written into the code. To choose the key where you register the middleware, write a function that takes the key and returns the middleware:

GITHUB_CODE_BLOCK lang="dart" file="../_example/middleware/auth_factory.dart" doctag="middleware-auth-factory" title="An API key check with a setting"

There are now three nested functions, and the call site changes with them. The plain `requireApiKey` was the middleware. This `requireApiKey('secret123')` returns one:

GITHUB_CODE_BLOCK lang="dart" file="../_example/middleware/auth_factory.dart" doctag="middleware-auth-factory-use" title="Passing the key"

The outer function also gives the middleware a place to keep state between requests, because Relic runs the three functions at different times. The outer one runs once, when `main` builds the route list. The middle one, which receives `next`, runs again for every request, since the router wraps the handler in its middleware each time it looks up a route. The inner one runs for every request too. A variable in the outer function is therefore shared by every request that passes through, and this middleware counts them:

GITHUB_CODE_BLOCK lang="dart" file="../_example/middleware/counting.dart" doctag="middleware-counting" title="Counting requests"

Two requests in a row get these headers among the others:

```text
x-request-count: 1
```

```text
x-request-count: 2
```

Move `var count = 0;` into the middle function and every response says 1.

### Which form to choose

Write middleware as a plain function when it needs nothing but `next`, as `timed` and the first `requireApiKey` do. It is the shorter form, you register it without parentheses, and hot reload picks up changes to it, because the router holds the function itself.

Write a function that returns middleware when the middleware takes settings, like the API key here or the logger that `logRequests` accepts, or when it keeps state across requests. The price is that `main` calls the outer function at startup, and hot reload leaves the closures it returned as they were. Restart the server after changing one, or register it inside a `RouterInjectable`, whose `injectIn` runs again on every reload, as the [Hot reload](./10-hot-reload.md) page explains.

## Which requests middleware sees

In the timing example, a request for a path with no route gets 404, and a POST to `/hello` gets 405. Neither prints a line. Middleware added with `use` belongs to routes, so it runs only for a request that matches one. A 404 or a 405 comes from the router, which found no route to run.

To put middleware in front of every request, make the app the only route of an outer app:

GITHUB_CODE_BLOCK lang="dart" file="../_example/middleware/every_request.dart" doctag="middleware-every-request" title="Logging every request"

The route `/**` with `any` matches every path and every method, so the outer app hands all requests to the inner one, and its middleware sees them all. Among the lines it logs are the 404 and the 405 that the inner app answered:

```text
2026-10-23T13:23:13.944789  0:00:00.000074 GET     [200] /hello
2026-10-23T13:23:13.962479  0:00:00.000425 GET     [404] /nothing
2026-10-23T13:23:13.998388  0:00:00.012566 POST    [405] /hello
```

## The order of middleware

When several middleware apply to the same route, each one wraps the next, like layers. A middleware that prints its name on the way in and on the way out shows the order they run in:

GITHUB_CODE_BLOCK lang="dart" file="../_example/middleware/order.dart" doctag="middleware-order-trace" title="A tracing middleware"

Register three of them, the one for `/api` first:

GITHUB_CODE_BLOCK lang="dart" file="../_example/middleware/order.dart" doctag="middleware-order-app" title="Three layers"

A request for `/api/users` prints:

```text
A: before
B: before
C: before
handler
C: after
B: after
A: after
```

Two rules produce that order. Middleware on a shorter path wraps middleware on a longer one, so `A` and `B`, registered at `/`, are outside `C`, registered at `/api`, even though `C` was registered first. Among middleware on the same path, the one registered first is outermost, so `A` wraps `B`. The result then travels back out through the same layers in reverse.

## Logging requests

Relic comes with one middleware ready to use. `logRequests` prints the time, the duration, the method, the status code and the path of every request it sees. It is a function that returns middleware, so you call it, `use('/', logRequests())`, and it takes an optional `logger` to send the lines somewhere other than the console. The [Hello world](../01-getting-started/02-hello-world-example.md) page shows it at work.

## CORS

Browsers stop a page on one origin from reading responses from another, unless the server allows it with [CORS](https://developer.mozilla.org/en-US/docs/Web/HTTP/CORS) headers. Before a request with custom headers or an unusual method, the browser sends a preflight `OPTIONS` request to ask. This middleware answers the preflight itself, and adds the `Access-Control-Allow-Origin` header to every other response:

GITHUB_CODE_BLOCK lang="dart" file="../_example/middleware/cors.dart" doctag="middleware-cors-basic" title="CORS middleware"

Since the middleware belongs to routes, a preflight for a route that only has GET gets 405 from the router and never reaches it. Register `Method.options` on each route that takes cross-origin requests:

GITHUB_CODE_BLOCK lang="dart" file="../_example/middleware/cors.dart" doctag="middleware-cors-routes" title="Routes for the CORS middleware"

## Pipeline

Before `use`, middleware was composed with the `Pipeline` class, which wraps a single handler. It still works, and the [Pipeline](./99-pipeline.md) page compares the two.

## Examples & further reading

### Examples

- **[Timing example](https://github.com/serverpod/relic/blob/main/packages/examples/middleware/timing.dart)** - The timing middleware from the start of this page.
- **[Order example](https://github.com/serverpod/relic/blob/main/packages/examples/middleware/order.dart)** - Traces the order of three middleware.
- **[Every request example](https://github.com/serverpod/relic/blob/main/packages/examples/middleware/every_request.dart)** - Logs the requests that match no route too.
- **[Auth example](https://github.com/serverpod/relic/blob/main/packages/examples/middleware/auth.dart)** - API key authentication as a plain function.
- **[Auth with a setting](https://github.com/serverpod/relic/blob/main/packages/examples/middleware/auth_factory.dart)** - The same check as a function that takes the key and returns middleware.
- **[Counting example](https://github.com/serverpod/relic/blob/main/packages/examples/middleware/counting.dart)** - State shared across requests.
- **[CORS example](https://github.com/serverpod/relic/blob/main/packages/examples/middleware/cors.dart)** - CORS handling.
- **[Pipeline example](https://github.com/serverpod/relic/blob/main/packages/examples/middleware/pipeline.dart)** - Pipeline and router side by side.

### API documentation

- [Middleware typedef](https://pub.dev/documentation/relic/latest/relic/Middleware.html) - Middleware function signature.
- [Pipeline class](https://pub.dev/documentation/relic/latest/relic/Pipeline-class.html) - Middleware composition around a single handler.
- [RelicApp class](https://pub.dev/documentation/relic/latest/relic/RelicApp-class.html) - Main application class with middleware support.

### Further reading

- [Cross-Origin Resource Sharing (CORS)](https://developer.mozilla.org/en-US/docs/Web/HTTP/CORS) - Mozilla documentation on CORS.
- [HTTP authentication](https://developer.mozilla.org/en-US/docs/Web/HTTP/Authentication) - Mozilla documentation on HTTP authentication.
