---
sidebar_position: 4
---

# Requests

The `Request` object represents an incoming HTTP request to your Relic server. It provides access to all information about the client's request, including the HTTP method, URL, headers, query parameters, and body content.

Every handler in Relic receives a request through the context object (`ctx.request`), allowing you to inspect and process the incoming data before generating a response.

## Understanding the Request Object

When a client makes a request to your server, Relic creates a `Request` object that encapsulates all the details of that request. This object is immutable and provides type-safe access to request data.

The request flows through your middleware pipeline and reaches your handler, where you can extract the information you need to process the request and generate an appropriate response.

### Key Request Properties

The `Request` object exposes several important properties:

- **`method`** - The HTTP method (GET, POST, PUT, DELETE, etc.) as a `Method` enum value
- **`url`** - The relative URL from the current handler's perspective, including query parameters
- **`requestedUri`** - The complete original URI that was requested
- **`headers`** - Type-safe access to HTTP headers
- **`body`** - The request body as a readable stream
- **`protocolVersion`** - The HTTP protocol version (typically "1.1")

## Accessing Request Data

### HTTP Method

The request method indicates what action the client wants to perform. Relic uses a type-safe `Method` enum rather than strings.

```dart
router.get('/info', (ctx) {
  final method = ctx.request.method;  // Method.get
  
  return ctx.respond(Response.ok(
    body: Body.fromString('Received a ${method.name} request'),
  ));
});
```

Common methods include `Method.get`, `Method.post`, `Method.put`, `Method.delete`, `Method.patch`, and `Method.options`.

### Request URL and Path

The `url` property provides the relative path and query parameters from the current handler's perspective. This is useful when your handler is mounted at a specific path prefix.

```dart
router.get('/users/:id', (ctx) {
  final url = ctx.request.url;
  final fullUri = ctx.request.requestedUri;
  
  print('Relative URL: $url');
  print('Full URI: $fullUri');
  
  return ctx.respond(Response.ok());
});
```

For a request to `http://localhost:8080/users/123?details=true`:

- `url.path` would be relative to the handler.
- `requestedUri` would be the complete url, including the query parameters.

## Working with Query Parameters

Query parameters are key-value pairs appended to the URL after a question mark (`?`). They're commonly used to pass optional data or filters to your endpoints.

### Single Value Parameters

Use `queryParameters` to access individual parameter values:

```dart
router.get('/search', (ctx) {
  final query = ctx.request.url.queryParameters['query'];
  final page = ctx.request.url.queryParameters['page'];
  
  if (query == null) {
    return ctx.respond(Response.badRequest(
      body: Body.fromString('Query parameter "query" is required'),
    ));
  }
  
  return ctx.respond(Response.ok(
    body: Body.fromString('Searching for: $query (page: ${page ?? "1"})'),
  ));
});
```

For the URL `/search?query=relic&page=2`:

- `query` = `"relic"`
- `page` = `"2"`

### Multiple Values

Some parameters can appear multiple times in a URL. Use `queryParametersAll` to access all values:

```dart
router.get('/filter', (ctx) {
  final tags = ctx.request.url.queryParametersAll['tag'] ?? [];
  
  return ctx.respond(Response.ok(
    body: Body.fromString('Filtering by tags: ${tags.join(", ")}'),
  ));
});
```

For the URL `/filter?tag=dart&tag=server&tag=web`:

- `tags` = `["dart", "server", "web"]`

## Reading Headers

HTTP headers carry metadata about the request. Relic provides type-safe access to common headers, automatically parsing them into appropriate Dart types.

### Type-Safe Header Access

Instead of working with raw string values, Relic's type-safe headers give you properly typed objects:

```dart
router.get('/info', (ctx) {
  final request = ctx.request;
  
  // Get typed values
  final mimeType = request.mimeType;  // MimeType? (from Content-Type)
  final userAgent = request.headers.userAgent;  // String?
  final contentLength = request.headers.contentLength;  // int?
  
  return ctx.respond(Response.ok(
    body: Body.fromString('Browser: ${userAgent ?? "Unknown"}'),
  ));
});
```

### Common Headers

Relic provides convenient accessors for frequently used headers:

- **`mimeType`** - MIME type from Content-Type (via `request.mimeType`, not `headers`)
- **`contentLength`** - Content length as an integer (`int?`)
- **`userAgent`** - User agent string (`String?`)
- **`authorization`** - Authentication credentials (`AuthorizationHeader?`)
- **`cookie`** - Cookie header (`CookieHeader?` - use `.cookies` property for `List<Cookie>`)
- **`host`** - Host header (`HostHeader?`)
- **`accept`** - Content types client accepts (`AcceptHeader?`)
- **`acceptEncoding`** - Encodings client supports (`AcceptEncodingHeader?`)

### Authorization Headers

The `authorization` header has special handling for different authentication schemes:

```dart
router.get('/protected', (ctx) {
  final auth = ctx.request.headers.authorization;
  
  if (auth is BearerAuthorizationHeader) {
    final token = auth.token;
    // Validate token...
  } else if (auth is BasicAuthorizationHeader) {
    final username = auth.username;
    final password = auth.password;
    // Validate credentials...
  } else {
    return ctx.respond(Response.unauthorized());
  }
  
  return ctx.respond(Response.ok());
});
```

## Reading the Request Body

The request body contains data sent by the client, typically in POST, PUT, or PATCH requests. Relic provides multiple ways to read body content depending on your needs.

:::warning Single Read Limitation

**The request body can only be read once.** This is because the body is a stream that gets consumed as it's read. Attempting to read the body multiple times will result in a `StateError`.

:::

```dart
// ❌ WRONG - This will throw an error
final first = await request.readAsString();
final second = await request.readAsString(); // StateError!

// ✅ CORRECT - Read once and store the result
final body = await request.readAsString();
// Use 'body' as many times as needed
```

### Reading as String

The most common way to read the body is as a string, which is perfect for JSON, XML, or plain text data:

```dart
router.post('/submit', (ctx) async {
  final bodyText = await ctx.request.readAsString();
  
  return ctx.respond(Response.ok(
    body: Body.fromString('Received: $bodyText'),
  ));
});
```

The `readAsString` method automatically decodes the body using the encoding specified in the Content-Type header (defaulting to UTF-8).

### Parsing JSON Data

For JSON APIs, read the body as a string and then parse it:

```dart
router.post('/api/users', (ctx) async {
  try {
    final bodyText = await ctx.request.readAsString();
    final data = jsonDecode(bodyText) as Map<String, dynamic>;
    
    final name = data['name'] as String?;
    final email = data['email'] as String?;
    
    if (name == null || email == null) {
      return ctx.respond(Response.badRequest(
        body: Body.fromString('Name and email are required'),
      ));
    }
    
    // Process user creation...
    
    return ctx.respond(Response.ok(
      body: Body.fromString('User created: $name'),
    ));
  } catch (e) {
    return ctx.respond(Response.badRequest(
      body: Body.fromString('Invalid JSON: $e'),
    ));
  }
});
```

### Reading as a Byte Stream

For large files or binary data, you can read the body as a stream of bytes to avoid loading everything into memory at once:

```dart
router.post('/upload', (ctx) async {
  final stream = ctx.request.read();  // Stream<Uint8List>
  
  int totalBytes = 0;
  await for (final chunk in stream) {
    totalBytes += chunk.length;
    // Process chunk...
  }
  
  return ctx.respond(Response.ok(
    body: Body.fromString('Uploaded $totalBytes bytes'),
  ));
});
```

### Checking if Body is Empty

Before attempting to read the body, you can check if it's empty:

```dart
router.post('/data', (ctx) {
  if (ctx.request.isEmpty) {
    return ctx.respond(Response.badRequest(
      body: Body.fromString('Request body is required'),
    ));
  }
  
  // Body exists, safe to read...
  return ctx.respond(Response.ok());
});
```

## Best Practices

### Validate Query Parameters

Always validate query parameters before using them, as they come from untrusted user input:

```dart
router.get('/page', (ctx) {
  final pageStr = ctx.request.url.queryParameters['page'];
  
  if (pageStr == null) {
    return ctx.respond(Response.badRequest(
      body: Body.fromString('Page parameter is required'),
    ));
  }
  
  final page = int.tryParse(pageStr);
  if (page == null || page < 1) {
    return ctx.respond(Response.badRequest(
      body: Body.fromString('Invalid page number'),
    ));
  }
  
  // Use validated page number...
  return ctx.respond(Response.ok());
});
```

### Handle Missing Headers Gracefully

Headers are optional, so always check for null:

```dart
router.get('/info', (ctx) {
  final userAgent = ctx.request.headers.userAgent;
  
  final message = userAgent != null
      ? 'Your browser: $userAgent'
      : 'Browser information not available';
  
  return ctx.respond(Response.ok(
    body: Body.fromString(message),
  ));
});
```

### Use Try-Catch for Body Parsing

Always wrap body parsing in try-catch blocks to handle malformed data:

```dart
router.post('/api/data', (ctx) async {
  try {
    final body = await ctx.request.readAsString();
    final data = jsonDecode(body);
    // Process data...
  } catch (e) {
    return ctx.respond(Response.badRequest(
      body: Body.fromString('Invalid request format'),
    ));
  }
});
```

## Summary

The `Request` object is your gateway to understanding what clients are asking for. Key takeaways:

- **Access request data** through `ctx.request` in your handlers
- **Use type-safe properties** like `method`, `url`, `headers`, and `body`
- **Read query parameters** with `url.queryParameters` (single values) or `url.queryParametersAll` (multiple values)
- **Handle headers safely** - they're optional and type-safe (e.g., `headers.userAgent`, `headers.authorization`)
- **Read body content once** - use `readAsString()` for text/JSON or `read()` for streaming
- **Always validate input** - query parameters, headers, and body content come from untrusted sources
- **Handle errors gracefully** - wrap JSON parsing and validation in try-catch blocks

With these fundamentals, you can build robust request handlers that safely process any client input.

## Examples

- **[`requets_response_example.dart`](https://github.com/serverpod/relic/blob/main/example/requets_response_example.dart)** - Comprehensive example covering requests, responses, and advanced routing patterns
  