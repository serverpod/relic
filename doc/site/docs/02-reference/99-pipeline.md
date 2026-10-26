---
sidebar_position: 99
sidebar_label: Pipeline (legacy)
---

# Pipeline (legacy)

Before routers had `use`, middleware went around a handler by way of a `Pipeline`. Relic keeps the class, because code that comes from Shelf is written with it, and because it is the most direct way to wrap one handler in several middleware. For new code, the `use` method described on the [Middleware](./08-middleware.md) page is usually the better fit.

## Building a pipeline

A `Pipeline` collects middleware one call at a time, and `addHandler` puts them around a handler:

GITHUB_CODE_BLOCK lang="dart" file="../_example/middleware/pipeline.dart" doctag="pipeline-usage" title="A pipeline around one handler"

`addServerHeader` is a middleware written as a plain function, which sets the `server` header of every response:

GITHUB_CODE_BLOCK lang="dart" file="../_example/middleware/pipeline.dart" doctag="middleware-add-server-header" title="A middleware that names the server"

Each call to `addMiddleware` returns a new `Pipeline`, so a pipeline is a value you can keep and extend. `addHandler` builds the finished handler, in which the middleware added first is the outermost. A request passes through `logRequests`, then `addServerHeader`, then reaches `greet`, and the response travels back out the same way.

## The same thing with use

The result of `addHandler` is an ordinary handler, so the example registers it on a route of its own. Next to it, the same two middleware go on another route with `use`:

GITHUB_CODE_BLOCK lang="dart" file="../_example/middleware/pipeline.dart" doctag="router-usage" title="The pipeline on a route, and the same with use"

The two routes answer alike:

```text
HTTP/1.1 200 OK
content-type: text/plain; charset=utf-8
date: Fri, 23 Oct 2026 12:13:46 GMT
content-length: 21
server: Relic

Hello from /pipeline
```

```text
HTTP/1.1 200 OK
content-type: text/plain; charset=utf-8
date: Fri, 23 Oct 2026 12:13:46 GMT
content-length: 19
server: Relic

Hello from /router
```

and each request leaves one line in the log:

```text
2026-10-23T14:13:46.292765  0:00:00.010513 GET     [200] /pipeline
2026-10-23T14:13:46.347657  0:00:00.000116 GET     [200] /router
```

## Pipeline or use

The difference lies in what the middleware are attached to. A pipeline wraps one handler, and its middleware run for every request that reaches that handler. With `use`, middleware belong to a path in a router, apply to every route below it, and run only for a request that matches one of those routes. A 404 or a 405 skips them. That is why moving a request logger from a pipeline in Shelf to `use` in Relic stops it from logging those two. The [Middleware](./08-middleware.md#which-requests-middleware-sees) page shows how to put middleware in front of every request.

## Examples & further reading

### Examples

- **[Pipeline example](https://github.com/serverpod/relic/blob/main/packages/examples/middleware/pipeline.dart)** - The program behind this page.

### API documentation

- [Pipeline class](https://pub.dev/documentation/relic/latest/relic/Pipeline-class.html) - Middleware composed around a single handler.
- [Middleware typedef](https://pub.dev/documentation/relic/latest/relic/Middleware.html) - Middleware function signature.
