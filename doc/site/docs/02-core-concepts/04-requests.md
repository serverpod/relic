# Requests

The `Request` object represents an incoming HTTP request to your Relic server. It provides access to all information about the client's request, including the HTTP method, URL, headers, query parameters, and body content.

Every handler in Relic receives a request through the context object (`ctx.request`), allowing you to inspect and process the incoming data before generating a response.

## Understanding the request object

When a client makes a request to your server, Relic creates a `Request` object that encapsulates all the details of that request. This object is immutable and provides type-safe access to request data.

The request flows through your middleware pipeline and reaches your handler, where you can extract the information you need to process the request and generate an appropriate response.

### Key request properties

The `Request` object exposes several important properties:

- **`method`** - The HTTP method (GET, POST, PUT, DELETE, etc.) as a `Method` enum value
- **`url`** - The relative URL from the current handler's perspective, including query parameters
- **`requestedUri`** - The complete original URI that was requested
- **`headers`** - Type-safe access to HTTP headers
- **`body`** - The request body as a readable stream
- **`protocolVersion`** - The HTTP protocol version (typically "1.1")

## Accessing request data

### Http method

The request method indicates what action the client wants to perform. Relic uses a type-safe `Method` enum rather than strings, which prevents typos and provides better IDE support.

```dart
app.get('/info', (ctx) {
  final method = ctx.request.method;  // Method.get

  return ctx.respond(Response.ok(
    body: Body.fromString('Received a ${method.name} request'),
  ));
});
```

Common methods include `Method.get`, `Method.post`, `Method.put`, `Method.delete`, `Method.patch`, and `Method.options`.

### Request url and path

The `url` property provides the relative path and query parameters from the current handler's perspective. This is particularly useful when your handler is mounted at a specific path prefix.

```dart
router.get('/users/:id', (ctx) {
  final id = ctx.pathParameters[#id]!;
  final url = ctx.request.url;
  final fullUri = ctx.request.requestedUri;

  print('Relative URL: $url');
  print('Full URI: $fullUri');

  return ctx.respond(Response.ok());
});
```

When handling a request to `http://localhost:8080/users/123?details=true`, the `url.path` contains the path relative to the handler, while `requestedUri` contains the complete URL including the domain and all query parameters.

## Working with query parameters

Query parameters are key-value pairs appended to the URL after a question mark (`?`). They're commonly used to pass optional data, filters, or pagination information to your endpoints.

### Single value parameters

You can access individual query parameter values through the `queryParameters` map. Each parameter is returned as a string, or null if not present.

```dart
app.get('/search', (ctx) {
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

When a client requests `/search?query=relic&page=2`, the query variable will contain `"relic"` and the page variable will contain `"2"`. Both values are strings, so you'll need to parse them if you need other types like integers.

### Multiple values

Some query parameters can appear multiple times in a URL to represent lists or arrays. The `queryParametersAll` map provides access to all values for each parameter name.

```dart
router.get('/filter', (ctx) {
  final tags = ctx.request.url.queryParametersAll['tag'] ?? [];

  return ctx.respond(Response.ok(
    body: Body.fromString('Filtering by tags: ${tags.join(", ")}'),
  ));
});
```

For a request to `/filter?tag=dart&tag=server&tag=web`, the tags variable will be a list containing `["dart", "server", "web"]`. This allows you to handle multiple selections or filters cleanly.

## Reading headers

HTTP headers carry metadata about the request, such as content type, authentication credentials, and client information. Relic provides type-safe access to common headers, automatically parsing them into appropriate Dart types.

### Type-safe header access

Instead of working with raw string values, Relic's type-safe headers give you properly typed objects. This eliminates parsing errors and provides better code completion in your IDE.

```dart
app.get('/headers-info', (ctx) {
  final request = ctx.request;

  // Get typed values
  final mimeType = request.mimeType;  // MimeType? (from Content-Type)
  final userAgent = request.headers.userAgent;  // String?
  final contentLength = request.headers.contentLength;  // int?

  return ctx.respond(Response.ok(
    body: Body.fromString(
      'Browser: ${userAgent ?? "Unknown"}, '
      'Content-Type: ${mimeType?.toString() ?? "None"}, '
      'Content-Length: ${contentLength ?? "Unknown"}',
    ),
  ));
});
```

In this example, the `mimeType` is automatically parsed into a `MimeType` object, and `contentLength` is parsed into an integer rather than a string. This type safety helps catch errors at compile time.

### Authorization headers

The `authorization` header receives special handling in Relic to distinguish between different authentication schemes like Bearer tokens and Basic authentication.

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

Relic automatically parses the authorization header and creates the appropriate header object type, making it easy to handle different authentication schemes in a type-safe manner.

## Reading the request body

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

### Reading as string

The most common way to read the body is as a string, which works well for JSON, XML, or plain text data. The `readAsString` method automatically handles character encoding based on the Content-Type header.

```dart
router.post('/submit', (ctx) async {
  final bodyText = await ctx.request.readAsString();

  return ctx.respond(Response.ok(
    body: Body.fromString('Received: $bodyText'),
  ));
});
```

The method defaults to UTF-8 encoding if no encoding is specified in the request headers.

### Parsing json data

For JSON APIs, you'll typically read the body as a string and then decode it using Dart's `jsonDecode` function. This two-step process gives you control over error handling.

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

This example shows proper validation of both the JSON structure and the required fields, providing clear error messages when something is wrong.

### Reading as a byte stream

For large files or binary data, you can read the body as a stream of bytes to avoid loading everything into memory at once. This is essential for handling file uploads or large payloads efficiently.

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

By processing the data in chunks, your server can handle large uploads without running out of memory.

### Checking if body is empty

Before attempting to read the body, you can check if it's empty using the `isEmpty` property. This is useful when you want to require a body for certain requests.

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

This check doesn't consume the body stream, so you can still read the body afterward.

## Best practices

### Validate query parameters

Always validate query parameters before using them, as they come from untrusted user input. Check for null values, parse strings to numbers safely, and validate ranges or formats.

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

### Handle missing headers gracefully

Headers are optional in HTTP, so always check for null values before using them. Provide sensible defaults or error messages when required headers are missing.

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

### Use try-catch for body parsing

Always wrap body parsing in try-catch blocks to handle malformed data gracefully. This prevents your server from crashing when clients send invalid requests.

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

The `Request` object is your gateway to understanding what clients are asking for. By leveraging Relic's type-safe API, you can build secure, reliable handlers that properly validate and process client input.

Key principles for working with requests include accessing data through `ctx.request`, using type-safe properties for methods and headers, reading query parameters safely, and handling request bodies appropriately. Remember that request bodies can only be read once, so design your handlers to consume the body early in the processing pipeline.

Always validate all incoming data since query parameters, headers, and body content come from untrusted sources. Use try-catch blocks for JSON parsing and validation to provide meaningful error responses. By following these patterns, you'll create handlers that are both secure and user-friendly.

## Examples

- **[`requets_response_example.dart`](https://github.com/serverpod/relic/blob/main/example/requets_response_example.dart)** - Comprehensive example covering requests, responses, and advanced routing patterns
