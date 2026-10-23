---
sidebar_position: 4
---

# Requests

A handler learns everything it knows about a request from the `Request` it receives. The quickest way to see what is in one is to print it. This handler does that for the request it answers:

GITHUB_CODE_BLOCK lang="dart" file="../_example/routing/request.dart" doctag="requests-inspect" title="A handler that describes its request"

The program on this page registers it, and the other handlers below, like this:

GITHUB_CODE_BLOCK lang="dart" file="../_example/routing/request.dart" doctag="requests-routes" title="The routes of the request example"

Send it a POST with a query and a small body:

```bash
curl -X POST 'http://localhost:8080/inspect?name=Nova&tag=a' -d 'hello'
```

```text
method:     POST
url:        http://localhost:8080/inspect?name=Nova&tag=a
path:       /inspect
query:      name=Nova&tag=a
protocol:   http11
user-agent: curl/8.7.1
from:       127.0.0.1:55826
body:       5 bytes
```

`method` is a value of the `Method` enum, and `value` is its name as HTTP writes it. `url` is the whole address the client asked for, scheme and host included, as a Dart `Uri`, and its `path` and `query` are the parts you will use most. `protocol` says which version of HTTP the request came in on. `headers` holds the headers, here read through the typed `userAgent` accessor. `connectionInfo` describes the network connection, and its `remote` address is the client, or the nearest proxy in front of the server. `body` is the five bytes curl sent, not yet read.

A request has a few more members that the sections below come back to. `target` is the path and query exactly as the client sent them. `cancelled` is a future that completes if the client goes away before the response is finished. `router` is the `RelicRouter` that routed the request. Within a route, `matchedPath` is the part of the path the route matched and `remainingPath` what is left after it, which the [Routing](./03-routing.md) page shows with tail segments.

## Query parameters

The query is the part of the URL after the question mark, name and value pairs joined by `&`. A search handler is the classic use:

GITHUB_CODE_BLOCK lang="dart" file="../_example/routing/request.dart" doctag="requests-search" title="Reading the query"

```bash
curl 'http://localhost:8080/search?q=relic&page=2&tag=dart&tag=web'
curl 'http://localhost:8080/search?q=relic'
```

```text
Searching for "relic", page 2, tags [dart, web]
Searching for "relic", page 1, tags []
```

The handler reads the query three ways. `queryParameters.raw` is a map from each name to its value, always a string, and null for a name that is not there. A typed accessor parses the value for you. `IntQueryParam('page')` declares that `page` is an integer, and calling `queryParameters` with it returns an `int?`, null when the page is absent. `queryParameters.get(pageParam)` would return a plain `int` and throw when the page is absent. Both throw for a value that does not parse, so `?page=two` gets a 500. `DoubleQueryParam` and `NumQueryParam` cover the other numbers, and `QueryParam<T>` takes a parser for any type, the same way `PathParam<T>` does for path parameters.

A name can appear more than once in a query, as `tag` does here. `raw` keeps the last value, and `url.queryParametersAll` has them all, as a list.

Without `q`, the handler answers 400 itself:

```text
HTTP/1.1 400 Bad Request
...
Add ?q= to search
```

## Headers

`request.headers` holds the request headers. Each common header has a typed accessor that parses its value, so you read a `userAgent` as a `String?`, a `contentLength` as an `int?`, and the `Authorization` header as an object that knows its scheme:

GITHUB_CODE_BLOCK lang="dart" file="../_example/routing/request.dart" doctag="requests-credentials" title="Reading the Authorization header"

```bash
curl http://localhost:8080/credentials
curl -H 'Authorization: Bearer abc123' http://localhost:8080/credentials
curl -u nova:secret http://localhost:8080/credentials
```

```text
No credentials
A bearer token: abc123
User nova, by password
```

curl's `-u` option sends Basic credentials, the user name and password encoded in base64, and `BasicAuthorizationHeader` decodes them again. When a header does not parse, reading its accessor throws, and Relic answers 400 with a message that says what was wrong:

```bash
curl -i -H 'Authorization: Basic !!!' http://localhost:8080/credentials
```

```text
HTTP/1.1 400 Bad Request
content-type: text/plain; charset=utf-8
date: Fri, 23 Oct 2026 11:59:32 GMT
content-length: 58

Invalid 'authorization' header: Invalid basic token format
```

For a header without an accessor, index the headers by name, `request.headers['X-Seen-By']`. That returns every value of the header, or null when it is absent.

## The body

The body is whatever the client sent after the headers, usually with a POST, PUT or PATCH. The simplest way to read it is as text:

GITHUB_CODE_BLOCK lang="dart" file="../_example/routing/request.dart" doctag="requests-text-body" title="Reading the body as text"

```bash
curl -X POST http://localhost:8080/shout -d 'hello, relic'
```

```text
HELLO, RELIC
```

`readAsString` decodes with the charset the request declares in its `Content-Type`, and with UTF-8 when it declares none. For JSON, decode that string yourself, and turn the ways it can go wrong into answers the client can act on:

GITHUB_CODE_BLOCK lang="dart" file="../_example/routing/request.dart" doctag="requests-json-body" title="Reading a JSON body"

```bash
curl -X POST http://localhost:8080/users -d '{"name":"Nova"}'
curl -X POST http://localhost:8080/users -d 'nope'
curl -X POST http://localhost:8080/users -d '{"age":3}'
```

```text
Created Nova
Not JSON
Expected a name
```

A body can be read only once. It may still be arriving from the network while the handler reads it, so there is nothing to rewind, and a second `readAsString` or `read` throws a `StateError`. Read it once and keep the result. For a large upload, read it as a stream of bytes with `read`, and pass `maxLength` to cap it. The [Body](./06-body.md) page covers streams, limits and the other ways to read.

`request.isEmpty` tells you whether a body has any bytes without reading it. It goes by the declared length, so a chunked body, whose length is not known in advance, is not empty by this test even if no bytes follow.

## Reading form data

Relic parses the two HTML form encodings, `application/x-www-form-urlencoded` and `multipart/form-data`. Each parser reads the request body, so call one of them once per request:

- `req.urlEncodedForm()` parses a urlencoded body.
- `req.multipartForm()` parses a multipart body, uploads included.
- `req.formData()` picks one of the two from the request's Content-Type.
- `req.multipart()` streams the parts of a multipart body one at a time, without collecting them.

### Typed fields

Read fields through accessors, the way typed query parameters work. `StringFormField`, `IntFormField`, `DoubleFormField` and `NumFormField` cover the common types, and `FormField<T>` takes your own decoder:

GITHUB_CODE_BLOCK lang="dart" file="../_example/basic/forms.dart" doctag="forms-typed-fields" title="Typed form fields"

The forms example serves this handler at `/signup`. curl's `-d` option sends a urlencoded form:

```bash
curl -d 'name=Nova&age=27&color=red&color=blue' http://localhost:8080/signup
curl -d 'name=Nova' http://localhost:8080/signup
```

```text
Nova, age 27, likes [red, blue]
Nova, age unknown, likes []
```

`fields.get` throws `MissingFormFieldException` when the field is absent, so a form without a name gets 400. Calling `fields` with the accessor returns null instead, which is how the age is optional. Both throw `InvalidFormFieldException` for a value that does not decode, so `age=old` gets 400 too, and `getAll` returns every value of a repeated field.

### Uploads

`multipartForm` keeps uploads in memory unless you pass an `uploadStorage`. `TempUploadStorage` writes each upload to its own temporary directory. Call `dispose` on the form when you are done, so the storage can delete them:

GITHUB_CODE_BLOCK lang="dart" file="../_example/basic/forms.dart" doctag="forms-upload" title="Multipart upload"

Each `UploadedFile` has the client's `filename`, its `bodyType`, its `size` and `read()` for its bytes.

### Limits

Every parser takes `FormLimits`, which caps the body size, the number of fields, files and parts, and the size of each field and file. `FormLimits.defaults` allows a 10 MB body, 100 fields and 8 files. A form over a limit throws `FormLimitExceededException`:

GITHUB_CODE_BLOCK lang="dart" file="../_example/basic/forms.dart" doctag="forms-limits" title="Form limits"

### Streaming parts

`multipart()` hands over each part as it arrives, as a `MultipartFieldPart`, a `MultipartFilePart` or a `MultipartOtherPart`. Read each part's body, or `discard()` it, as the example does:

GITHUB_CODE_BLOCK lang="dart" file="../_example/basic/forms.dart" doctag="forms-stream" title="Streaming multipart parts"

### Form errors

Every form error is a `FormException` with a `statusCode`. A body that is not a form gets 415, a malformed one or a missing or invalid field 400, and a form over a limit 413. A handler that lets the exception through gets that status from the server. For a body that is not a form, is malformed or is over a limit, the server also closes the connection, since part of the body may be unread. Catch `FormException` to answer differently, as the upload examples do.

## Modifying requests

A request's `url` and `headers` are final. To pass on a request with something changed, a middleware makes a copy with `copyWith`, which carries over every field it is not given:

GITHUB_CODE_BLOCK lang="dart" file="../_example/routing/request.dart" doctag="requests-copy" title="Passing on a copy with an extra header"

```bash
curl http://localhost:8080/seen
```

```text
Seen by [tagRequest]
```

`headers.transform` starts from the headers the request already has, so the copy keeps them all and adds one. `copyWith` also takes a new `url`, which must be absolute and without a fragment, and a new `body`.

### Forwarding requests

A copy with a new URL does not reach another route by itself, because the routing has already happened. To route it again, pass it to `request.forwardTo`, which sends it through the same router, middleware included. The [Routing](./03-routing.md#forwarding-a-request) page shows an example, and what to keep in mind about path parameters. `forwardTo` throws a `StateError` for a request that no `RelicRouter` routed, such as one handled by a bare `Pipeline`.

## Examples & further reading

### Examples

- **[Requests example](https://github.com/serverpod/relic/blob/main/packages/examples/routing/request.dart)** - The program behind this page.
- **[Forms example](https://github.com/serverpod/relic/blob/main/packages/examples/basic/forms.dart)** - HTML forms, uploads, limits and streamed parts.

### API documentation

- [Request class](https://pub.dev/documentation/relic/latest/relic/Request-class.html) - HTTP request object.
- [Method enum](https://pub.dev/documentation/relic/latest/relic/Method.html) - HTTP methods enumeration.
- [Headers class](https://pub.dev/documentation/relic/latest/relic/Headers-class.html) - Type-safe HTTP headers.
- [Body class](https://pub.dev/documentation/relic/latest/relic/Body-class.html) - Request/response body handling.
- [AuthorizationHeader class](https://pub.dev/documentation/relic/latest/relic/AuthorizationHeader-class.html) - Authorization header parsing.

### Further reading

- [HTTP request methods](https://developer.mozilla.org/en-US/docs/Web/HTTP/Methods) - Mozilla documentation on HTTP methods.
- [HTTP headers](https://developer.mozilla.org/en-US/docs/Web/HTTP/Headers) - Mozilla documentation on HTTP headers.
- [What is a URL?](https://developer.mozilla.org/en-US/docs/Learn/Common_questions/What_is_a_URL) - Mozilla documentation on URL structure and query parameters.
