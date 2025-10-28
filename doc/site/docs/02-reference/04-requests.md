---
sidebar_position: 4
---

# Requests

The `Request` object represents an incoming HTTP request to your Relic server. It provides access to all information about the client's request, including the HTTP method, URL, headers, query parameters, and body content.

Every handler in Relic receives a request through the context object (`ctx.request`), allowing you to inspect and process the incoming data before generating a response.

## Understanding the request object

When a client makes a request to your server, Relic creates a `Request` object that encapsulates all the details of that request. This object is immutable and provides type-safe access to request data.

The request flows through your middleware pipeline and reaches your handler, where you can extract the information you need to process the request and generate an appropriate response.

### Key request properties

The `Request` object exposes several important properties:

- **`method`** - The HTTP method (GET, POST, PUT, DELETE, etc.) as a `Method` enum value.
- **`url`** - The relative URL from the current handler's perspective, including query parameters.
- **`requestedUri`** - The complete original URI that was requested.
- **`headers`** - Type-safe access to HTTP headers.
- **`body`** - The request body as a readable stream.
- **`protocolVersion`** - The HTTP protocol version (typically "1.1").

## Accessing request data

### Http method

The request method indicates what action the client wants to perform. Relic uses a type-safe `Method` enum rather than strings, which prevents typos and provides better IDE support.

```dart reference
https://github.com/serverpod/relic/blob/main/example/routing/request_example.dart#L11-L17
```

Common methods include `Method.get`, `Method.post`, `Method.put`, `Method.delete`, `Method.patch`, and `Method.options`.

### Request url and path

The `url` property provides the relative path and query parameters from the current handler's perspective. This is particularly useful when your handler is mounted at a specific path prefix.

```dart reference
https://github.com/serverpod/relic/blob/main/example/routing/request_example.dart#L20-L29
```

When handling a request to `http://localhost:8080/users/123?details=true`, the `url.path` contains the path relative to the handler, while `requestedUri` contains the complete URL including the domain and all query parameters.

## Working with query parameters

Query parameters are key-value pairs appended to the URL after a question mark (`?`). They're commonly used to pass optional data, filters, or pagination information to your endpoints.

### Single value parameters

You can access individual query parameter values through the `queryParameters` map. Each parameter is returned as a string, or null if not present.

```dart reference
https://github.com/serverpod/relic/blob/main/example/routing/request_example.dart#L32-L49
```

When a client requests `/search?query=relic&page=2`, the query variable will contain `"relic"` and the page variable will contain `"2"`. Both values are strings, so you'll need to parse them if you need other types like integers.

### Multiple values

Some query parameters can appear multiple times in a URL to represent lists or arrays. The `queryParametersAll` map provides access to all values for each parameter name.

```dart reference
https://github.com/serverpod/relic/blob/main/example/routing/request_example.dart#L52-L60
```

For a request to `/filter?tag=dart&tag=server&tag=web`, the tags variable will be a list containing `["dart", "server", "web"]`. This allows you to handle multiple selections or filters cleanly.

## Reading headers

HTTP headers carry metadata about the request, such as content type, authentication credentials, and client information. Relic provides type-safe access to common headers, automatically parsing them into appropriate Dart types.

### Type-safe header access

Instead of working with raw string values, Relic's type-safe headers give you properly typed objects. This eliminates parsing errors and provides better code completion in your IDE.

```dart reference
https://github.com/serverpod/relic/blob/main/example/routing/request_example.dart#L63-L80
```

In this example, the `mimeType` is automatically parsed into a `MimeType` object, and `contentLength` is parsed into an integer rather than a string. This type safety helps catch errors at compile time.

### Authorization headers

The `authorization` header receives special handling in Relic to distinguish between different authentication schemes like Bearer tokens and Basic authentication.

```dart reference
https://github.com/serverpod/relic/blob/main/example/routing/request_example.dart#L83-L106
```

Relic automatically parses the authorization header and creates the appropriate header object type, making it easy to handle different authentication schemes in a type-safe manner.

## Reading the request body

The request body contains data sent by the client, typically in POST, PUT, or PATCH requests. Relic provides multiple ways to read body content depending on your needs.

:::warning Single read limitation

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

```dart reference
https://github.com/serverpod/relic/blob/main/example/routing/request_example.dart#L109-L114
```

The method defaults to UTF-8 encoding if no encoding is specified in the request headers.

### Parsing json data

For JSON APIs, you'll typically read the body as a string and then decode it using Dart's `jsonDecode` function. This two-step process gives you control over error handling.

```dart reference
https://github.com/serverpod/relic/blob/main/example/routing/request_example.dart#L117-L143
```

This example shows proper validation of both the JSON structure and the required fields, providing clear error messages when something is wrong.

### Reading as a byte stream

For large files or binary data, you can read the body as a stream of bytes to avoid loading everything into memory at once. This is essential for handling file uploads or large payloads efficiently.

```dart reference
https://github.com/serverpod/relic/blob/main/example/routing/request_example.dart#L146-L158
```

By processing the data in chunks, your server can handle large uploads without running out of memory.

### Checking if body is empty

Before attempting to read the body, you can check if it's empty using the `isEmpty` property. This is useful when you want to require a body for certain requests.

```dart reference
https://github.com/serverpod/relic/blob/main/example/routing/request_example.dart#L161-L170
```

This check doesn't consume the body stream, so you can still read the body afterward.

## Best practices

### Validate query parameters

Always validate query parameters before using them, as they come from untrusted user input. Check for null values, parse strings to numbers safely, and validate ranges or formats.

```dart reference
https://github.com/serverpod/relic/blob/main/example/routing/request_example.dart#L173-L193
```

### Handle missing headers gracefully

Headers are optional in HTTP, so always check for null values before using them. Provide sensible defaults or error messages when required headers are missing.

```dart reference
https://github.com/serverpod/relic/blob/main/example/routing/request_example.dart#L196-L205
```

### Use try-catch for body parsing

Always wrap body parsing in try-catch blocks to handle malformed data gracefully. This prevents your server from crashing when clients send invalid requests.

```dart
app.post('/api/data', (ctx) async {
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

- **[`request_example.dart`](https://github.com/serverpod/relic/blob/main/example/routing/request_example.dart)** - Example covering requests
