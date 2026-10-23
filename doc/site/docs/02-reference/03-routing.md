---
sidebar_position: 3
---

# Routing

A handler answers a request. Routing decides which handler, by looking at two things in the request, its method and its path. This page builds up the routes of two small programs, and shows what each request gets back.

## Methods and paths

The first program registers a handful of routes, each with a method, a path and the handler that answers:

GITHUB_CODE_BLOCK lang="dart" file="../_example/routing/basic_routing.dart" doctag="routing-methods" title="Routes by method and path"

`get`, `post`, `put` and `delete` are shortcuts for `add` with the matching `Method`, as the `patch` route shows by calling `add` itself. There is a shortcut for every method Relic knows, `get`, `head`, `post`, `put`, `delete`, `patch`, `options`, `trace` and `connect`. `anyOf` registers one handler for a set of methods, and `any` registers it for all of them.

The method picks the handler as much as the path does:

```bash
curl http://localhost:8080/
curl -X POST http://localhost:8080/
```

```text
You asked for /
You posted to /
```

For a method that the path has no route for, the router answers 405 and lists the methods it does have in the `allow` header:

```bash
curl -i -X DELETE http://localhost:8080/
```

```text
HTTP/1.1 405 Method Not Allowed
date: Fri, 23 Oct 2026 11:56:48 GMT
content-length: 0
allow: GET, HEAD, POST
```

A path with no route at all gets 404. The [Hello world](../01-getting-started/02-hello-world-example.md) page shows both, and how to answer unmatched requests yourself with a `fallback`.

## HEAD requests

HEAD is in that `allow` list, although the program registers no HEAD route. A HEAD request asks for the headers that a GET would get, without the body. When a path has a GET route and no HEAD route, the GET handler answers it:

```bash
curl -I http://localhost:8080/
```

```text
HTTP/1.1 200 OK
content-type: text/plain; charset=utf-8
date: Fri, 23 Oct 2026 11:56:48 GMT
content-length: 16
```

The 16 is the length of `You asked for /` and its newline, although no body was sent. The adapter cancels the body's stream without reading it, and a body built with `Body.lazy` never makes its stream at all. The handler sees `Method.head` on `request.method`, so it can skip work that only the body needs.

A path can still have a HEAD route of its own, and that route takes precedence, whatever order the routes are added in. The one exception to the fallback is a GET handler that returns a `Hijack` or a `WebSocketUpgrade`. Relic cannot strip a body from bytes that the handler writes itself, so a HEAD request to such a route gets 405. The [Handlers](./01-handlers.md#taking-over-the-connection) page shows a hijacking handler with a HEAD route of its own.

## Path parameters

Fixed paths only go so far. A route segment that starts with a colon is a parameter, which matches any value and remembers it. The second program starts with one:

GITHUB_CODE_BLOCK lang="dart" file="../_example/routing/dynamic_segments.dart" doctag="routing-raw-param" title="A path parameter"

```bash
curl http://localhost:8080/users/42
```

```text
User 42
```

`pathParameters.raw` maps the name of each parameter, as a Dart symbol, to the segment it matched, and the value is always a string. To get a number, declare a typed accessor for the parameter and read the value through it:

GITHUB_CODE_BLOCK lang="dart" file="../_example/routing/dynamic_segments.dart" doctag="routing-typed-param" title="A typed path parameter"

GITHUB_CODE_BLOCK lang="dart" file="../_example/routing/dynamic_segments.dart" doctag="routing-typed-param-route" title="Its route"

```bash
curl http://localhost:8080/orders/42
```

```text
Order 42, and the next one is 43
```

`get` parses the segment and returns an `int`, so `id + 1` is arithmetic rather than string concatenation. When the segment does not parse, `get` throws a `FormatException`, and a request for `/orders/abc` gets a 500. Besides `IntPathParam`, there are `DoublePathParam` and `NumPathParam` for numbers.

Calling `pathParameters` with the accessor, instead of calling `get`, returns null when the route has no such parameter. That lets one handler serve a route with the parameter and a route without it:

GITHUB_CODE_BLOCK lang="dart" file="../_example/routing/dynamic_segments.dart" doctag="routing-optional-param" title="An optional parameter"

GITHUB_CODE_BLOCK lang="dart" file="../_example/routing/dynamic_segments.dart" doctag="routing-optional-param-routes" title="Its two routes"

Requests for `/posts` and `/posts/3` get:

```text
Posts, page 1
Posts, page 3
```

For any other type, give `PathParam` the function that parses it:

GITHUB_CODE_BLOCK lang="dart" file="../_example/routing/dynamic_segments.dart" doctag="routing-custom-param-inline" title="A parameter of your own type"

To reuse an accessor like that, make it a class with the parser built in, the way `IntPathParam` is made:

GITHUB_CODE_BLOCK lang="dart" file="../_example/routing/dynamic_segments.dart" doctag="routing-custom-param-class" title="A reusable accessor"

The program reads the date of `/events/:date` with it, and a request for `/events/2026-10-23` gets:

```text
Events in month 10 of 2026
```

## Wildcards and tails

A `*` segment matches any value, as a parameter does, but keeps none, for when the value does not matter:

GITHUB_CODE_BLOCK lang="dart" file="../_example/routing/dynamic_segments.dart" doctag="routing-wildcard" title="A wildcard segment"

A request for `/files/report.pdf/download` gets `Downloading a file`.

A `**` at the end of a route matches the rest of the path, however many segments that is. The part it matched is the request's `remainingPath`:

GITHUB_CODE_BLOCK lang="dart" file="../_example/routing/dynamic_segments.dart" doctag="routing-tail" title="A tail segment"

```bash
curl http://localhost:8080/static/css/site.css
```

```text
Serving /css/site.css
```

This is how a handler for a whole directory learns which file was asked for, and the [Static files](./08-static-files.md) page relies on it.

## Which route wins

The program registers both `/static/**` and `/static/special/report`. A request for the report matches both routes, and gets the more specific one:

```text
/static/special/report   The special report
/static/special/other    Serving /special/other
```

The router walks the path one segment at a time, and tries a literal segment before a parameter, a wildcard or a tail. When the literal path leads to a dead end, it backs up and tries the alternatives. The last two routes of the program show that backtracking at work:

GITHUB_CODE_BLOCK lang="dart" file="../_example/routing/dynamic_segments.dart" doctag="routing-backtracking" title="Two routes that need backtracking"

A request for `/shop/789/profile` follows the literal `shop` all the way to the end. A request for `/shop/789` starts down the same literal `shop`, and `789` matches `:id`, but that route needs a third segment, `profile`, and the path has ended. So the router backs up to the first segment, tries `:entity` instead, and `/:entity/:id` matches:

```text
/shop/789           A shop with id 789
/shop/789/profile   A shop profile
```

Without backtracking, the request for `/shop/789` would have committed to the literal `shop` and failed. Because of these rules, the order you register routes in does not change which route wins, so routers built in separate modules combine without surprises.

The routes live in a trie, a tree with one level per path segment. A lookup takes time in proportion to the number of segments in the path, not the number of routes. Backtracking visits each node at most once, so even the worst lookup does no more work than trying every route in turn.

## Forwarding a request

Sometimes a handler wants another route to answer, without sending the client a redirect. It makes a copy of the request with a new URL, and forwards the copy through the same router:

GITHUB_CODE_BLOCK lang="dart" file="../_example/routing/basic_routing.dart" doctag="routing-forward" title="Forwarding an old path to a new one"

```bash
curl http://localhost:8080/v1/users
```

```text
The users, from /v2/users
```

`forwardTo` sends the copy through all of the routing of the router that handled the original, middleware included, which calling the other handler directly would skip. Read the forwarded request's parameters with `rawPathParameters`. The copy shares its context properties with the original, so `pathParameters` and `queryParameters` that were read before forwarding keep their old values. The [Requests](./04-requests.md#modifying-requests) page has more on `copyWith` and `forwardTo`.

## Examples & further reading

### Examples

- **[Basic routing example](https://github.com/serverpod/relic/blob/main/packages/examples/routing/basic_routing.dart)** - Routes by method and path, and forwarding.
- **[Dynamic segments example](https://github.com/serverpod/relic/blob/main/packages/examples/routing/dynamic_segments.dart)** - Path parameters, wildcards, tails and backtracking.

### API documentation

- [RelicApp class](https://pub.dev/documentation/relic/latest/relic/RelicApp-class.html) - Main application class with routing methods.
- [Router class](https://pub.dev/documentation/relic/latest/relic/Router-class.html) - URL router for mapping path patterns.
- [Method enum](https://pub.dev/documentation/relic/latest/relic/Method.html) - HTTP methods enumeration.
