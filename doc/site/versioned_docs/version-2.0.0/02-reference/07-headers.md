---
sidebar_position: 7
---

# Headers

A header arrives as text, a name and a value on one line. Relic keeps the text, and parses it into a value with a type when a handler asks. This handler reads the same header both ways:

GITHUB_CODE_BLOCK lang="dart" file="../_example/routing/headers.dart" doctag="headers-raw-and-typed" title="A header read raw and typed"

The program on this page registers it, and the other handlers below, like this:

GITHUB_CODE_BLOCK lang="dart" file="../_example/routing/headers.dart" doctag="headers-routes" title="The routes of the headers example"

Send it an `Accept` header with two media ranges and their weights:

```bash
curl -H 'Accept: text/html;q=0.9, */*;q=0.1' http://localhost:8080/accept
```

```text
raw:   [text/html;q=0.9, */*;q=0.1]
typed: text/html at 0.9, */* at 0.1
```

`headers['accept']` gives the text, as a list because a header can appear more than once. `headers.accept` gives an `AcceptHeader`, whose `mediaRanges` have a `type`, a `subtype` and a `quality`, so the handler compares weights as numbers and never splits a string. Without the option, curl sends `Accept: */*`, and the typed read says `*/* at 1.0`, with the default weight filled in.

Every common header has an accessor like that, from `userAgent` as a `String?` to `cookie` as a list of cookies. A header is parsed once per request, and the parsed value is kept for the next read.

## Three ways to read

A typed accessor is a constant on the `Headers` class, `Headers.range` for the `Range` header, and there are three ways to read through it. The getter, `headers.range`, is the usual one, and it is null when the header is absent:

GITHUB_CODE_BLOCK lang="dart" file="../_example/routing/headers.dart" doctag="headers-range" title="A header that may be absent"

```bash
curl -H 'Range: bytes=0-499, 1000-' http://localhost:8080/file
curl http://localhost:8080/file
```

```text
bytes 0-499, 1000-
The whole file
```

`headers(Headers.range)` is the same read, written as a call. The third way, `headers.get(Headers.range)`, returns a plain `RangeHeader` rather than a `RangeHeader?`, and throws when the header is absent. That suits a header the handler cannot do without:

GITHUB_CODE_BLOCK lang="dart" file="../_example/routing/headers.dart" doctag="headers-get" title="A header the handler requires"

```bash
curl -H 'If-None-Match: "v1", W/"v2"' http://localhost:8080/compare
curl -i http://localhost:8080/compare
```

```text
Compare against v1, weak v2
```

```text
HTTP/1.1 400 Bad Request
content-type: text/plain; charset=utf-8
date: Mon, 26 Oct 2026 08:25:59 GMT
content-length: 30

Missing 'if-none-match' header
```

Each entity tag came back as an `ETagHeader` with its `value` and whether it `isWeak`, the quotes and the `W/` already dealt with. Without the header, `get` threw, and Relic answered 400 with the name of the missing header. Path, query and form parameters read the same three ways, which the [Routing](./03-routing.md#path-parameters) and [Requests](./04-requests.md#query-parameters) pages show.

## A header that does not parse

The same handler that read the ranges above gets a `Range` that is not one:

```bash
curl -i -H 'Range: bytes=abc' http://localhost:8080/file
```

```text
HTTP/1.1 400 Bad Request
content-type: text/plain; charset=utf-8
date: Mon, 26 Oct 2026 08:25:59 GMT
content-length: 37

Invalid 'range' header: Invalid range
```

The accessor throws an `InvalidHeaderException`, and Relic turns it into a 400 that names the header. The handler never ran. A handler that would rather answer itself reads with `tryGet`, which gives null for a value that does not parse as well as for one that is absent.

For a header Relic has no accessor for, index the headers by name. `headers['X-Request-Id']` gives its values as text, or null. The name is matched whatever its case.

## Writing headers

A response carries its headers in a `Headers`, and `Headers.build` hands you a set to fill in:

GITHUB_CODE_BLOCK lang="dart" file="../_example/routing/headers.dart" doctag="headers-build" title="A response with typed and named headers"

```bash
curl -i http://localhost:8080/cached
```

```text
HTTP/1.1 200 OK
etag: "v1"
content-type: text/plain; charset=utf-8
cache-control: public, max-age=3600
date: Mon, 26 Oct 2026 08:25:59 GMT
content-length: 20
x-request-id: 7f3a

Keep me for an hour
```

The typed setters wrote `cache-control` and `etag` in the form HTTP expects, the quotes around the tag included. A header without a setter goes in by name, as a list of values. The `Body` wrote `content-type` and `content-length`, and the [Responses](./05-responses.md#headers) page shows what happens to those two when a handler sets them itself.

A set of headers cannot be changed once built. `transform` takes one and returns another with the changes applied, and the original keeps its values, so a middleware that adds a header to a request never changes what another handler sees. The [Requests](./04-requests.md#modifying-requests) page shows a middleware doing that.

### A value that must not reach the wire

A header ends at the line break. A value with a line break in it would end the header early, and whatever followed would be read as the next header. This handler copies a query parameter into a header:

GITHUB_CODE_BLOCK lang="dart" file="../_example/routing/headers.dart" doctag="headers-echo" title="A header from a query parameter"

```bash
curl -i 'http://localhost:8080/echo?v=hello'
```

```text
HTTP/1.1 200 OK
content-type: text/plain; charset=utf-8
date: Mon, 26 Oct 2026 08:25:59 GMT
content-length: 13
x-echo: hello

Echoed hello
```

Now send it a value with a carriage return and a line feed in it, `%0D%0A`, followed by a header of the client's choosing:

```bash
curl -i 'http://localhost:8080/echo?v=a%0D%0AX-Injected:%20yes'
```

```text
HTTP/1.1 500 Internal Server Error
content-type: text/plain; charset=utf-8
date: Mon, 26 Oct 2026 08:25:59 GMT
content-length: 21

Internal Server Error
```

The write threw a `FormatException`, and the log says why:

```text
FormatException: Header "x-echo" value must not contain CR, LF or NUL (at character 2)
```

No header reached the client, injected or otherwise. Every write checks its value, the typed setters and the named ones alike, and a name that is not an HTTP token is refused the same way. A handler that takes header values from its callers can catch the exception and answer 400.

## A header of your own

Every typed header in Relic is a `HeaderAccessor`, a `HeaderName` paired with a `HeaderCodec` that parses and writes the value. Nothing stops a program from declaring one. This one types an `X-RateLimit-Remaining` header as an `int`:

GITHUB_CODE_BLOCK lang="dart" file="../_example/routing/headers.dart" doctag="headers-custom" title="A typed header for X-RateLimit-Remaining"

`HeaderCodec.single` takes the parser and the encoder for a header with one value, and `HeaderCodec` takes a parser over all the values for a header that may repeat. The two extensions give the header a getter on `HeaderValues`, which both `Headers` and `MutableHeaders` are, and a setter on `MutableHeaders`, so it reads and writes like the built-in headers. A middleware uses the setter to tell each caller how much of its quota is left:

GITHUB_CODE_BLOCK lang="dart" file="../_example/routing/headers.dart" doctag="headers-custom-middleware" title="A middleware that sets the header"

The program gives `/api` a quota of two. Three requests get:

```bash
curl -i http://localhost:8080/api/ping
```

```text
HTTP/1.1 200 OK
content-type: text/plain; charset=utf-8
date: Mon, 26 Oct 2026 08:25:59 GMT
content-length: 5
x-ratelimit-remaining: 1

pong
```

```text
HTTP/1.1 200 OK
content-type: text/plain; charset=utf-8
date: Mon, 26 Oct 2026 08:25:59 GMT
content-length: 5
x-ratelimit-remaining: 0

pong
```

```text
HTTP/1.1 429 Status 429
date: Mon, 26 Oct 2026 08:25:59 GMT
content-length: 0
```

The header counted down from the quota, and the third request was refused. `assign` encoded the `int` through the codec, and a client built on Relic reads it back with `headers.rateLimitRemaining`, as an `int?`, through the same accessor.

## Which headers are typed

The accessors cover the headers a server reads and writes most. These are the ones you will meet first, with the type each reads as:

| Header | Accessor | Type |
| --- | --- | --- |
| `Accept` | `accept` | `AcceptHeader` |
| `Authorization` | `authorization` | `AuthorizationHeader` |
| `Cache-Control` | `cacheControl` | `CacheControlHeader` |
| `Content-Length` | `contentLength` | `int` |
| `Content-Type` | `contentType` | `ContentTypeHeader` |
| `Cookie` | `cookie` | `CookieHeader` |
| `ETag` | `etag` | `ETagHeader` |
| `Host` | `host` | `HostHeader` |
| `If-None-Match` | `ifNoneMatch` | `IfNoneMatchHeader` |
| `Location` | `location` | `Uri` |
| `Range` | `range` | `RangeHeader` |
| `Set-Cookie` | `setCookie` | `SetCookieHeader` |
| `User-Agent` | `userAgent` | `String` |

The [Headers class](https://pub.dev/documentation/relic/latest/relic/Headers-class.html) lists them all, the CORS, security and forwarding headers among them.

## Examples & further reading

### Examples

- **[Headers example](https://github.com/serverpod/relic/blob/main/packages/examples/routing/headers.dart)** - The program behind this page.

### API documentation

- [Headers class](https://pub.dev/documentation/relic/latest/relic/Headers-class.html) - Headers and their typed accessors.
- [MutableHeaders class](https://pub.dev/documentation/relic/latest/relic/MutableHeaders-class.html) - The builder side of Headers.
- [HeaderAccessor class](https://pub.dev/documentation/relic/latest/relic/HeaderAccessor-class.html) - A typed header.
- [HeaderCodec class](https://pub.dev/documentation/relic/latest/relic/HeaderCodec-class.html) - The parser and encoder behind an accessor.

### Further reading

- [HTTP headers](https://developer.mozilla.org/en-US/docs/Web/HTTP/Headers) - Mozilla documentation on HTTP headers.
- [HTTP semantics, field values](https://www.rfc-editor.org/rfc/rfc9110#name-field-values) - The RFC on what a header value may contain.
