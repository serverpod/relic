---
sidebar_position: 5
---

# Responses

A handler that answers in the ordinary way returns a `Response`. Before looking at the class, it helps to look at what a response becomes on the wire. This handler:

GITHUB_CODE_BLOCK lang="dart" file="../_example/routing/response.dart" doctag="responses-hello" title="A handler that says hello"

sends these bytes in answer to a request for `/hello`:

```bash
curl -i http://localhost:8080/hello
```

```text
HTTP/1.1 200 OK
content-type: text/plain; charset=utf-8
date: Fri, 23 Oct 2026 12:01:43 GMT
content-length: 7

Hello!
```

A response has three parts, and all three are visible here. The first line is the status line, with the version of HTTP, the status code 200 and its reason phrase, `OK`. The headers follow, one to a line, up to an empty line. Then comes the body, the seven bytes of `Hello!` and its newline. `Response.ok` chose the status code. `Body.fromString` produced the body, and with it the `content-type` and `content-length` headers. Relic added the `date` header itself. The rest of this page goes through the three parts in that order.

## The status code

`Response.ok` is one of a set of named constructors, one for each common status code, so that a handler says `Response.notFound()` rather than `Response(404)`. The error constructors fill in a short body when you give them none:

GITHUB_CODE_BLOCK lang="dart" file="../_example/routing/response.dart" doctag="responses-errors" title="A response for a missing user"

```bash
curl -i http://localhost:8080/users/2
```

```text
HTTP/1.1 404 Not Found
content-type: text/plain; charset=utf-8
date: Fri, 23 Oct 2026 12:01:43 GMT
content-length: 9

Not Found
```

The constructors cover the codes that most handlers need. `ok`, `noContent` and `notModified` report success. `movedPermanently`, `found` and `seeOther` redirect. `badRequest`, `unauthorized`, `forbidden`, `notFound`, `contentTooLarge`, `internalServerError` and `notImplemented` report errors. For any other code, call the `Response` constructor with the number:

GITHUB_CODE_BLOCK lang="dart" file="../_example/routing/response.dart" doctag="responses-status" title="A status code without a constructor"

```text
HTTP/1.1 418 Status 418
content-type: text/plain; charset=utf-8
date: Fri, 23 Oct 2026 12:01:43 GMT
content-length: 24

I refuse to brew coffee
```

The reason phrase is `Status 418`, because the server knows no name for that code. Clients go by the number, so the phrase does no harm.

### Redirects

A redirect is a status code, and a `location` header that says where to go instead. The redirect constructors take that location:

GITHUB_CODE_BLOCK lang="dart" file="../_example/routing/response.dart" doctag="responses-redirect" title="A permanent redirect"

```text
HTTP/1.1 301 Moved Permanently
location: /hello
date: Fri, 23 Oct 2026 12:01:44 GMT
content-length: 0
```

With `-L`, curl follows the redirect, and prints what `/hello` answers, `Hello!`. `movedPermanently`, a 301, tells clients to use the new address from now on. `found`, a 302, says that the move is temporary. `seeOther`, a 303, says to fetch the new address with GET, which suits the answer to a form that was posted.

### No content

Some responses have nothing to say beyond their status. A successful DELETE is a typical case, and `Response.noContent()` answers it with 204:

GITHUB_CODE_BLOCK lang="dart" file="../_example/routing/response.dart" doctag="responses-empty" title="An answer without a body"

```bash
curl -s -o /dev/null -w '%{http_code}\n' -X DELETE http://localhost:8080/users/1
```

```text
204
```

A 204 response never has a body. For a 200 with an empty body, give `Response.ok` a `Body.empty()`, or no body at all.

## The body

The body can be text, HTML, JSON, raw bytes or a stream. `Body.fromString` takes a `mimeType` when the text is not plain text:

GITHUB_CODE_BLOCK lang="dart" file="../_example/routing/response.dart" doctag="responses-kinds" title="HTML and JSON"

The two handlers answer with these types and bodies:

```text
content-type: text/html; charset=utf-8

<h1>Hello</h1>
```

```text
content-type: application/json; charset=utf-8

{"name":"Nova","age":27}
```

The `Body` decides the `content-type` and `content-length` headers. The [Body](./06-body.md) page covers the rest of it, bytes, streams and files, and how Relic detects the type when you give none.

## Headers

Any other header goes in the `headers` of the response. `Headers.build` hands you a set of headers to fill in, with typed setters for the common headers and plain names for the rest:

GITHUB_CODE_BLOCK lang="dart" file="../_example/routing/response.dart" doctag="responses-headers" title="A response with headers of its own"

```text
HTTP/1.1 200 OK
x-served-by: relic
content-type: text/plain; charset=utf-8
cache-control: public, max-age=3600
date: Fri, 23 Oct 2026 12:01:44 GMT
content-length: 20

Keep me for an hour
```

The typed `cacheControl` setter took a `CacheControlHeader` and wrote `public, max-age=3600`, so a misspelled directive cannot reach the client. Relic writes header names in lowercase, and HTTP treats names the same whatever their case.

Three headers are not yours to set. The `Body` decides `content-type`, `content-length` and the chunked transfer coding, and Relic drops those three when a handler puts them in the headers:

GITHUB_CODE_BLOCK lang="dart" file="../_example/routing/response.dart" doctag="responses-dropped-header" title="A Content-Type that has no effect"

```text
HTTP/1.1 200 OK
content-type: text/plain; charset=utf-8
date: Fri, 23 Oct 2026 12:01:44 GMT
content-length: 21

Plain text after all
```

The `application/json` from the headers is gone. Set the type with `mimeType:` on the `Body`, and the length of a stream with `contentLength:` on `Body.fromDataStream`.

## Answering HEAD

A HEAD request gets the same status line and headers as GET, and no body. Relic sends a GET route's response to a HEAD request without its body, so a handler rarely has to think about HEAD at all. The [Routing](./03-routing.md#head-requests) page has the details.

## Examples & further reading

### Examples

- **[Responses example](https://github.com/serverpod/relic/blob/main/packages/examples/routing/response.dart)** - The program behind this page.

### API documentation

- [Response class](https://pub.dev/documentation/relic/latest/relic/Response-class.html) - HTTP response object.
- [Body class](https://pub.dev/documentation/relic/latest/relic/Body-class.html) - Request/response body handling.
- [Headers class](https://pub.dev/documentation/relic/latest/relic/Headers-class.html) - Type-safe HTTP headers.
- [MimeType class](https://pub.dev/documentation/relic/latest/relic/MimeType-class.html) - MIME type handling.

### Further reading

- [HTTP response status codes](https://developer.mozilla.org/en-US/docs/Web/HTTP/Status) - Mozilla documentation on HTTP status codes.
- [HTTP headers](https://developer.mozilla.org/en-US/docs/Web/HTTP/Headers) - Mozilla documentation on HTTP headers.
- [MIME types](https://developer.mozilla.org/en-US/docs/Web/HTTP/Basics_of_HTTP/MIME_types) - Mozilla documentation on MIME types.
