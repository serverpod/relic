---
sidebar_position: 5
---

# Responses

A `Response` object represents the HTTP response your server sends back to the client. It encapsulates the status code, headers, and body content that together form the complete answer to a client's request.

In Relic, handlers return a `Response` as part of the `Result` type. The response tells the client whether the request succeeded, failed, or requires further action, and provides any requested data or error information.

## Understanding HTTP responses

An HTTP response consists of three main parts:

1. **Status Code** - A three-digit number indicating the outcome (e.g., 200 for success, 404 for not found)
2. **Headers** - Metadata about the response (content type, caching rules, cookies, etc.)
3. **Body** - The actual content being sent (HTML, JSON, files, or empty)

## Response convenience methods

Relic's `Response` class provides static convenience methods for common HTTP status codes, making it easy to create appropriate responses without memorizing numeric codes. Instead of writing `Response(400)`, you can simply use `Response.badRequest()`.

## Creating responses

### Success responses

Success responses (2xx status codes) indicate that the request was received, understood, and processed successfully.

The most common response indicates the request succeeded and returns the requested data:

GITHUB_CODE_BLOCK lang="dart" [src](https://raw.githubusercontent.com/serverpod/relic/main/example/routing/request_response_example.dart) doctag="basic-request-response" title="200 OK text response"

### Error responses

Error responses (4xx, 5xx status codes) indicate that the request was invalid or cannot be fulfilled due to server or client side issues.

#### 400 Bad Request

The request is malformed or contains invalid data:

GITHUB_CODE_BLOCK lang="dart" [src](https://raw.githubusercontent.com/serverpod/relic/main/example/routing/request_response_example.dart) doctag="json-api-complete" title="400 Bad Request JSON error"

### Custom status codes

For status codes without a dedicated constructor, use the general `Response` constructor:

GITHUB_CODE_BLOCK lang="dart" [src](https://raw.githubusercontent.com/serverpod/relic/main/example/routing/request_response_example.dart) doctag="custom-status" title="Custom status code"

:::tip
For a comprehensive list of HTTP status codes, check out [Mozilla's HTTP Status Codes documentation](https://developer.mozilla.org/en-US/docs/Web/HTTP/Reference/Status).

To ensure consistency and avoid memorizing numeric codes, use Relic's convenient response constructors like `Response.ok()`, `Response.badRequest()`, and `Response.notFound()` etc.
:::

## Working with response bodies

The response body contains the actual data you're sending to the client. Relic's `Body` class provides a unified way to handle different content types.

### Text responses

For plain text responses, use `Body.fromString()`:

GITHUB_CODE_BLOCK lang="dart" [src](https://raw.githubusercontent.com/serverpod/relic/main/example/routing/request_response_example.dart) doctag="basic-request-response" title="Text response"

By default, Relic infers the MIME type from the content. For plain text, it sets `text/plain`.

### HTML responses

To serve HTML content, specify the MIME type explicitly:

GITHUB_CODE_BLOCK lang="dart" [src](https://raw.githubusercontent.com/serverpod/relic/main/example/routing/request_response_example.dart) doctag="html-response" title="HTML response"

### JSON responses

For JSON APIs, encode your data and specify the JSON MIME type:

GITHUB_CODE_BLOCK lang="dart" [src](https://raw.githubusercontent.com/serverpod/relic/main/example/routing/request_response_example.dart) doctag="path-params-complete" title="JSON response"

### Binary data

For images, PDFs, or other binary content, use `Body.fromData()`:

GITHUB_CODE_BLOCK lang="dart" [src](https://raw.githubusercontent.com/serverpod/relic/main/example/routing/request_response_example.dart) doctag="binary-response" title="Binary response"

Relic automatically infers the MIME type from the binary data when possible.

### Streaming responses

For large files or generated content, stream the data instead of loading it all into memory:

GITHUB_CODE_BLOCK lang="dart" [src](https://raw.githubusercontent.com/serverpod/relic/main/example/routing/request_response_example.dart) doctag="streaming-response" title="Streaming response"

### Empty responses

Some responses don't need a body. Use `Body.empty()` or simply omit the body parameter:

GITHUB_CODE_BLOCK lang="dart" [src](https://raw.githubusercontent.com/serverpod/relic/main/example/routing/request_response_example.dart) doctag="empty-responses" title="Empty responses"

## Setting response headers

Headers provide metadata about your response. Use the `Headers` class to build type-safe headers:

GITHUB_CODE_BLOCK lang="dart" [src](https://raw.githubusercontent.com/serverpod/relic/main/example/routing/request_response_example.dart) doctag="response-headers" title="Set response headers"

:::tip
For a comprehensive list of HTTP headers, check out [Mozilla's HTTP Headers documentation](https://developer.mozilla.org/en-US/docs/Web/HTTP/Headers).
:::

## Final tips

Effective HTTP responses are the foundation of reliable web applications. Beyond just sending data back to clients, responses communicate the outcome of operations, guide client behavior, and provide crucial feedback for debugging and user experience.

Choose status codes that accurately reflect what happened - success codes for completed operations, client error codes for invalid requests, and server error codes for unexpected failures.

The key principle is that every handler must return a response. Make those responses meaningful, consistent, and helpful as they represent your API's contract with the world.

## Examples & further reading

### Examples

- **[Responses example](https://github.com/serverpod/relic/blob/main/example/routing/request_response_example.dart)** - Comprehensive example covering complete request-response cycles.

### API documentation

- [Response class](https://pub.dev/documentation/relic/latest/relic/Response-class.html) - HTTP response object.
- [Body class](https://pub.dev/documentation/relic/latest/relic/Body-class.html) - Request/response body handling.
- [Headers class](https://pub.dev/documentation/relic/latest/relic/Headers-class.html) - Type-safe HTTP headers.
- [MimeType class](https://pub.dev/documentation/relic/latest/relic/MimeType-class.html) - MIME type handling.

### Further reading

- [HTTP response status codes](https://developer.mozilla.org/en-US/docs/Web/HTTP/Status) - Mozilla documentation on HTTP status codes.
- [HTTP headers](https://developer.mozilla.org/en-US/docs/Web/HTTP/Headers) - Mozilla documentation on HTTP headers.
- [MIME types](https://developer.mozilla.org/en-US/docs/Web/HTTP/Basics_of_HTTP/MIME_types) - Mozilla documentation on MIME types.
