---
sidebar_position: 6
---

# Body

Every request and response carries its content in a `Body`. A body is more than its bytes. It also knows how many bytes it has, and what kind of data they are, and from those two facts Relic writes the `Content-Length` and `Content-Type` headers. The quickest way to see that is to build a few bodies and ask them. This function prints what a body knows:

GITHUB_CODE_BLOCK lang="dart" file="../_example/basic/body_types.dart" doctag="body-describe" title="Printing what a body knows"

## Bodies from text

`Body.fromString` makes a body from a string. Give it some different strings:

GITHUB_CODE_BLOCK lang="dart" file="../_example/basic/body_types.dart" doctag="body-from-string" title="Bodies from strings"

```text
plain text           text/plain; charset=utf-8         13 bytes
JSON                 application/json; charset=utf-8   20 bytes
HTML                 text/html; charset=utf-8          28 bytes
XML                  application/xml; charset=utf-8    28 bytes
accents and emoji    text/plain; charset=utf-8         11 bytes
Latin-1              text/plain; charset=iso-8859-1    5 bytes
CSV                  text/csv; charset=utf-8           8 bytes
```

Without a `mimeType`, the body looks at the first characters of the text, after any whitespace, to decide its type. A `{` or a `[` makes it JSON, an XML declaration makes it XML, `<!DOCTYPE html` or `<html` makes it HTML, and anything else is plain text. It does not parse the text, so a string that merely starts with a brace is still called JSON. The encoding is UTF-8 unless you pass another, and the type carries it as the `charset` parameter.

The length is a count of bytes, not of characters. `Héllo 🌍` has seven characters, but in UTF-8 the `é` takes two bytes and the globe four, which makes eleven. In Latin-1, `Héllo` takes one byte per character, so the same word is five bytes there, and the charset says so. When you know the type and the text cannot show it, as with CSV, pass `mimeType`.

## Bodies from bytes

`Body.fromData` makes a body from bytes, such as an image read from a file with `await file.readAsBytes()`:

GITHUB_CODE_BLOCK lang="dart" file="../_example/basic/body_types.dart" doctag="body-from-data" title="Bodies from bytes"

```text
PNG signature        image/png                         8 bytes
PDF signature        application/pdf                   8 bytes
unknown bytes        application/octet-stream          3 bytes
bytes as SVG         image/svg+xml                     6 bytes
empty                (none)                            0 bytes
```

Many file formats begin with a few fixed bytes, a signature, and the body recognizes the common ones. Eight bytes are enough to tell a PNG image or a PDF document. Bytes it does not recognize are `application/octet-stream`, which tells a client only that they are binary data. An SVG image is text inside, so its bytes have no signature, and it needs its `mimeType` given. `Body.empty()` has no bytes and no type, and is what a response without a body uses.

## Streams

A string or a list of bytes has to be in memory before you can make a body of it. For data that is large, or produced while the response is going out, give `Body.fromDataStream` a stream of bytes instead. This handler counts down, half a second per line:

GITHUB_CODE_BLOCK lang="dart" file="../_example/basic/body.dart" doctag="body-streaming-chunked" title="A streamed countdown"

The program on this page registers its handlers like this:

GITHUB_CODE_BLOCK lang="dart" file="../_example/basic/body.dart" doctag="body-routes" title="The routes of the body example"

```bash
curl -i -N http://localhost:8080/countdown
```

```text
HTTP/1.1 200 OK
content-type: text/plain; charset=utf-8
transfer-encoding: chunked
date: Fri, 23 Oct 2026 12:04:54 GMT

3...
2...
1...
Liftoff!
```

There is no `content-length` this time. The stream does not know how long it will be, so Relic sends the body with chunked transfer encoding, in which each piece of the body carries its own length and an empty piece marks the end. curl strips those lengths before it prints. That framing is part of HTTP/1.1, so an HTTP/1.0 client gets the body ended by closing the connection instead. When you do know the length, pass it as `contentLength`, and the response gets a `content-length` header and no chunks.

With the dart:io adapter, the four lines of the countdown reach the client together, after a second and a half. The adapter buffers the output of a streamed body, and sends small pieces when more data has gathered or the stream has ended. Large pieces, such as the blocks a file is read in, go out while the stream is still running. For events that must arrive the moment they happen, the [Handlers](./01-handlers.md#taking-over-the-connection) page writes them on a hijacked connection.

## Files, opened only when needed

Serving a file as a stream means opening it. But not every response is sent. A HEAD request wants only the headers, and a request can fail before its response goes out. `Body.lazy` takes a function that opens the stream, and calls it only when the body is read:

GITHUB_CODE_BLOCK lang="dart" file="../_example/basic/body.dart" doctag="body-lazy-file" title="A file that opens when read"

The path is relative to the working directory, so run the program from `packages/examples`, where `_static_files` is. The function prints a line when it opens the file. A GET for `/greeting` reads the body, so the server prints:

```text
opening _static_files/hello.txt
```

A HEAD request for `/greeting` gets the same headers, `content-length: 9` included, and the server prints nothing. The length came from `file.length()`, and the file itself was never opened.

## Reading a body

A body can be read once. The program below reads a body with `readAll`, which returns all of its bytes, and then tries again:

GITHUB_CODE_BLOCK lang="dart" file="../_example/basic/body_types.dart" doctag="body-read-once" title="Reading a body twice"

```text
read 5 bytes
Bad state: The 'read' method can only be called once on a Request/Response object.
```

A request body may still be arriving from the network while the handler reads it, so there is nothing to rewind, and Relic treats every body the same way. Any second `read`, `readAll` or `readAsString` throws, even when nothing listened to the first stream. Read the body once and keep what you got.

There are three ways to read. `read` returns the bytes as a stream, for handling them piece by piece. `readAll` collects them into one `Uint8List`, and for a body made from a string or bytes it returns them at once. On a request, `readAsString` decodes the bytes into text, with the charset the request declares, and UTF-8 when it declares none.

Each of them takes a `maxLength`, and throws `MaxBodySizeExceeded` when the body is longer:

GITHUB_CODE_BLOCK lang="dart" file="../_example/basic/body_types.dart" doctag="body-max-length" title="A body over its limit"

```text
MaxBodySizeExceeded: Body exceeded 10 bytes
```

## Limits on uploads

On a server, `maxLength` is how a handler protects itself from an upload that is too large. This one reads the request body as a stream, counts the bytes, and gives up after a megabyte:

GITHUB_CODE_BLOCK lang="dart" file="../_example/basic/body.dart" doctag="body-upload-limit" title="An upload capped at 1 MB"

Half a megabyte gets through, and two megabytes do not:

```bash
head -c 500000 /dev/zero | curl --data-binary @- http://localhost:8080/upload
head -c 2000000 /dev/zero | curl -i --data-binary @- http://localhost:8080/upload
```

```text
Received 500000 bytes
```

```text
HTTP/1.1 413 Request Entity Too Large
...
Over 1 MB
```

When the request declares its length, as curl does here, `read` throws before a single byte is read. When the length is not declared, as with a chunked upload, the stream throws once the count passes the limit. Either way the handler answers 413.

## Looking at a body in middleware

Since a body can be read only once, a middleware that reads it must put a body back before passing the request on. The new body should have the same bytes and the same type, so that a handler further down can still parse it:

GITHUB_CODE_BLOCK lang="dart" file="../_example/basic/body.dart" doctag="body-inspect-middleware" title="Reading a body and putting it back"

`Body.fromBytes` takes the type as given, without guessing, and keeps its parameters. That matters for a multipart form, whose type carries the `boundary` that separates its parts. The program puts this middleware in front of a handler that parses a form, and both kinds of form survive the trip:

```bash
curl -d 'name=Nova' http://localhost:8080/signup
curl -F name=Nova http://localhost:8080/signup
```

```text
Hello, Nova
Hello, Nova
```

The server prints what the middleware saw:

```text
a body of 9 bytes, application/x-www-form-urlencoded
a body of 155 bytes, multipart/form-data
```

## The headers a body decides

The body is the only source of `Content-Length` and `Content-Type` on a response, and of the chunked transfer encoding. Relic drops those headers when a handler sets them on the response's `Headers`, as the [Responses](./05-responses.md#headers) page shows.

## Examples & further reading

### Examples

- **[Body types example](https://github.com/serverpod/relic/blob/main/packages/examples/basic/body_types.dart)** - Builds bodies of each kind and prints what they decided.
- **[Body example](https://github.com/serverpod/relic/blob/main/packages/examples/basic/body.dart)** - Streams, lazy files, upload limits and middleware that reads a body.

### API documentation

- [Body class](https://pub.dev/documentation/relic/latest/relic/Body-class.html) - HTTP request/response body handling.
- [BodyType class](https://pub.dev/documentation/relic/latest/relic/BodyType-class.html) - MIME type and encoding information.
- [MimeType class](https://pub.dev/documentation/relic/latest/relic/MimeType-class.html) - MIME type handling.

### Further reading

- [MIME types](https://developer.mozilla.org/en-US/docs/Web/HTTP/Basics_of_HTTP/MIME_types) - Mozilla documentation on MIME types.
- [Character encodings](https://developer.mozilla.org/en-US/docs/Web/HTTP/Headers/Content-Type) - Mozilla documentation on Content-Type header.
- [Streaming and chunked transfer encoding](https://developer.mozilla.org/en-US/docs/Web/HTTP/Headers/Transfer-Encoding) - Mozilla documentation on transfer encoding.
