---
sidebar_position: 5
---

# Responses

A `Response` object represents the HTTP response your server sends back to the client. It encapsulates the status code, headers, and body content that together form the complete answer to a client's request.

In Relic, every handler must return a response (wrapped in a context). The response tells the client whether the request succeeded, failed, or requires further action, and provides any requested data or error information.

## Understanding HTTP responses

An HTTP response consists of three main parts:

1. **Status Code** - A three-digit number indicating the outcome (e.g., 200 for success, 404 for not found)
2. **Headers** - Metadata about the response (content type, caching rules, cookies, etc.)
3. **Body** - The actual content being sent (HTML, JSON, files, or empty)

## Response convenience methods

Relic's `Response` class provides static convenience methods for common HTTP status codes, making it easy to create appropriate responses without memorizing numeric codes. Instead of writing `Response(400)`, you can simply use `Response.badRequest()`.

## Creating responses

#### Success responses

Success responses (2xx status codes) indicate that the request was received, understood, and processed successfully.

The most common response indicates the request succeeded and returns the requested data:

```dart
app.get('/status', (ctx) {
  return ctx.respond(Response.ok(
    body: Body.fromString('Status is Ok'),
  ));
});
```

### Error responses

Error responses (4xx, 5xx status codes) indicate that the request was invalid or cannot be fulfilled due to server or client side issues.

#### 400 Bad Request

The request is malformed or contains invalid data:

```dart
app.post('/api/users', (ctx) async {
  try {
    throw
  } catch (e) {
    return ctx.respond(Response.badRequest(
      body: Body.fromString('Invalid JSON'),
    ));
  }
});
```

### Custom status codes

For status codes without a dedicated constructor, use the general `Response` constructor:

```dart
app.get('/teapot', (ctx) {
  return ctx.respond(Response(
    418,  // I'm a teapot
    body: Body.fromString('I refuse to brew coffee'),
  ));
});
```

:::tip
For a comprehensive list of HTTP status codes, check out [Mozilla's HTTP Status Codes documentation](https://developer.mozilla.org/en-US/docs/Web/HTTP/Reference/Status).

To ensure consistency and avoid memorizing numeric codes, use Relic's convenient response constructors like `Response.ok()`, `Response.badRequest()`, and `Response.notFound()` etc.
:::

## Working with Response bodies

The response body contains the actual data you're sending to the client. Relic's `Body` class provides a unified way to handle different content types.

### Text responses

For plain text responses, use `Body.fromString()`:

```dart
Response.ok(
  body: Body.fromString('Hello, World!'),
)
```

By default, Relic infers the MIME type from the content. For plain text, it sets `text/plain`.

### HTML responses

To serve HTML content, specify the MIME type explicitly:

```dart
app.get('/page', (ctx) {
  final html = '''
<!DOCTYPE html>
<html>
<head><title>My Page</title></head>
<body><h1>Welcome!</h1></body>
</html>
''';
  
  return ctx.respond(Response.ok(
    body: Body.fromString(html, mimeType: MimeType.html),
  ));
});
```

### JSON responses

For JSON APIs, encode your data and specify the JSON MIME type:

```dart
import 'dart:convert';

app.get('/api/users/:id', (ctx) {
  final user = {
    'id': 123,
    'name': 'Alice',
    'email': 'alice@example.com',
  };
  
  return ctx.respond(Response.ok(
    body: Body.fromString(
      jsonEncode(user),
      mimeType: MimeType.json,
    ),
  ));
});
```

### Binary data

For images, PDFs, or other binary content, use `Body.fromData()`:

```dart
import 'dart:typed_data';

app.get('/image.png', (ctx) {
  final imageBytes = Uint8List.fromList(loadImageData());
  
  return ctx.respond(Response.ok(
    body: Body.fromData(imageBytes),
  ));
});
```

Relic automatically infers the MIME type from the binary data when possible.

### Streaming responses

For large files or generated content, stream the data instead of loading it all into memory:

```dart
app.get('/large-file', (ctx) {
  Stream<Uint8List> dataStream = getLargeFileStream();
  
  return ctx.respond(Response.ok(
    body: Body.fromDataStream(
      dataStream,
      mimeType: MimeType.octetStream,
      contentLength: fileSize,  // Optional but recommended
    ),
  ));
});
```

### Empty responses

Some responses don't need a body. Use `Body.empty()` or simply omit the body parameter:

```dart
// Explicitly empty
Response.ok(body: Body.empty())

// Or use noContent() which implies an empty body
Response.noContent()
```

## Setting response headers

Headers provide metadata about your response. Use the `Headers` class to build type-safe headers:

```dart
app.get('/api/data', (ctx) {
  final headers = Headers.build((h) {
    // Set cache control
    h.cacheControl = CacheControlHeader(
      maxAge: 3600,
      publicCache: true,
    );
    
    // Set custom header
    h['X-Custom-Header'] = ['value'];
  });
  
  return ctx.respond(Response.ok(
    headers: headers,
    body: Body.fromString('{"status": "ok"}', mimeType: MimeType.json),
  ));
});
```

:::tip
For a comprehensive list of HTTP headers, check out [Mozilla's HTTP Headers documentation](https://developer.mozilla.org/en-US/docs/Web/HTTP/Headers).
:::

## Examples

- **[`response_example.dart`](https://github.com/serverpod/relic/blob/main/example/response_example.dart)** - Example covering responses

## Summary

Effective HTTP responses are the foundation of reliable web applications. Beyond just sending data back to clients, responses communicate the outcome of operations, guide client behavior, and provide crucial feedback for debugging and user experience.

Choose status codes that accurately reflect what happened - success codes for completed operations, client error codes for invalid requests, and server error codes for unexpected failures.

The key principle is that every handler must return a response. Make those responses meaningful, consistent, and helpful as they represent your API's contract with the world.
