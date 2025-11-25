---
sidebar_position: 4
---

# Requests

The `Request` object represents an incoming HTTP request to your Relic server. It provides access to all information about the client's request, including the HTTP method, URL, headers, query parameters, and body content.

Every handler in Relic receives a `Request` object as a parameter, allowing you to inspect and process the incoming data before generating a response.

## Understanding the request object

When a client makes a request to your server, Relic creates a `Request` object that encapsulates all the details of that request. This object provides type-safe access to request data.

Note on mutability:

- `Request.headers` is immutable.
- `Request.body` is a `Body` wrapper and is mutable (handlers or middleware may replace it). The underlying body stream can be read only once.

The request flows through your middleware pipeline and reaches your handler, where you can extract the information you need to process the request and generate an appropriate response.

### Key request properties

The `Request` object exposes several important properties:

- **`method`** - The HTTP method (GET, POST, PUT, DELETE, etc.) as a `Method` enum value.
- **`url`** - The complete original URI that was requested.
- **`headers`** - Type-safe access to HTTP headers.
- **`body`** - The request body wrapped in a `Body` helper. Use `await request.readAsString()` for text, or `request.read()` to access the byte stream. Both are single-read.
- **`protocolVersion`** - The HTTP protocol version (typically `1.1`).

## Accessing request data

### HTTP method

The request method indicates what action the client wants to perform. Relic uses a type-safe `Method` enum rather than strings, which prevents typos and provides better IDE support.

GITHUB_CODE_BLOCK lang="dart" file="../_example/routing/request_response.dart" doctag="basic-request-response" title="HTTP method"

Common methods include `Method.get`, `Method.post`, `Method.put`, `Method.delete`, `Method.patch`, and `Method.options`.

### Request url and path

The `url` property provides the relative path and query parameters from the current handler's perspective. This is particularly useful when your handler is mounted at a specific path prefix.

GITHUB_CODE_BLOCK lang="dart" file="../_example/routing/request_response.dart" doctag="path-params-complete" title="Path parameters and URL"

## Working with query parameters

Query parameters are key-value pairs appended to the URL after a question mark (`?`). They're commonly used to pass optional data, filters, or pagination information to your endpoints.

### Single value parameters

You can access individual query parameter values through the `queryParameters` map. Each parameter is returned as a string, or null if not present.

GITHUB_CODE_BLOCK lang="dart" file="../_example/routing/request_response.dart" doctag="query-params-complete" title="Query parameters"

When a client requests `/search?query=relic&page=2`, the query variable will contain `"relic"` and the page variable will contain `"2"`. Both values are strings, so you'll need to parse them if you need other types like integers.

### Multiple values

Some query parameters can appear multiple times in a URL to represent lists or arrays. The `queryParametersAll` map provides access to all values for each parameter name.

GITHUB_CODE_BLOCK lang="dart" file="../_example/routing/request_response.dart" doctag="query-multi-complete" title="Multiple query values"

For a request to `/filter?tag=dart&tag=server&tag=web`, the tags variable will be a list containing `["dart", "server", "web"]`. This allows you to handle multiple selections or filters cleanly.

## Reading headers

HTTP headers carry metadata about the request, such as content type, authentication credentials, and client information. Relic provides type-safe access to common headers, automatically parsing them into appropriate Dart types.

### Type-safe header access

Instead of working with raw string values, Relic's type-safe headers give you properly typed objects. This eliminates parsing errors and provides better code completion in your IDE.

GITHUB_CODE_BLOCK lang="dart" file="../_example/routing/request_response.dart" doctag="headers-complete" title="Type-safe headers"

In this example, the `mimeType` is automatically parsed into a `MimeType` object, and `contentLength` is parsed into an integer rather than a string. This type safety helps catch errors at compile time.

### Authorization headers

The `authorization` header receives special handling in Relic to distinguish between different authentication schemes like Bearer tokens and Basic authentication.

GITHUB_CODE_BLOCK lang="dart" file="../_example/routing/request_response.dart" doctag="auth-complete" title="Authorization header parsing"

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

GITHUB_CODE_BLOCK lang="dart" file="../_example/routing/request_response.dart" doctag="body-handling-complete" title="Read body as string"

The method defaults to UTF-8 encoding if no encoding is specified in the request headers.

### Parsing JSON data

For JSON APIs, you'll typically read the body as a string and then decode it using Dart's `jsonDecode` function. This two-step process gives you control over error handling.

GITHUB_CODE_BLOCK lang="dart" file="../_example/routing/request_response.dart" doctag="json-api-complete" title="Parse JSON body with validation"

This example shows proper validation of both the JSON structure and the required fields, providing clear error messages when something is wrong.

### Reading as a byte stream

For large files or binary data, you can read the body as a stream of bytes to avoid loading everything into memory at once. This is essential for handling file uploads or large payloads efficiently.

GITHUB_CODE_BLOCK lang="dart" file="../_example/routing/request_response.dart" doctag="upload-complete" title="Read body as byte stream"

By processing the data in chunks, your server can handle large uploads without running out of memory.

### Checking if body is empty

Before attempting to read the body, you can check if it's empty using the `isEmpty` property. This is useful when you want to require a body for certain requests.

:::warning
`isEmpty` is based on the known content length when available. For requests using chunked transfer encoding (unknown length up front), `isEmpty` may return `false` even if no data is ultimately sent. Prefer defensive reads for streaming uploads.
:::

GITHUB_CODE_BLOCK lang="dart" file="../_example/routing/request_response.dart" doctag="upload-complete" title="Body empty check"

This check doesn't consume the body stream, so you can still read the body afterward.

## Final tips

The `Request` object is your gateway to understanding what clients are asking for. By leveraging Relic's type-safe API, you can build secure, reliable handlers that properly validate and process client input.

Key principles for working with requests include accessing data through the `Request` parameter, using type-safe properties for methods and headers, reading query parameters safely, and handling request bodies appropriately. Remember that request bodies can only be read once, so design your handlers to consume the body early in the processing pipeline.

Always validate all incoming data since query parameters, headers, and body content come from untrusted sources. Use try-catch blocks for JSON parsing and validation to provide meaningful error responses. By following these patterns, you'll create handlers that are both secure and user-friendly.

## Examples & further reading

### Examples

- **[Requests example](https://github.com/serverpod/relic/blob/main/example/routing/request_response.dart)** - Comprehensive example covering complete request-response cycles.

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
