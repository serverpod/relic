---
sidebar_position: 5
---

# Responses

A `Response` object represents the HTTP response your server sends back to the client. It encapsulates the status code, headers, and body content that together form the complete answer to a client's request.

In Relic, every handler must return a response (wrapped in a context). The response tells the client whether the request succeeded, failed, or requires further action, and provides any requested data or error information.

## Understanding HTTP Responses

An HTTP response consists of three main parts:

1. **Status Code** - A three-digit number indicating the outcome (e.g., 200 for success, 404 for not found)
2. **Headers** - Metadata about the response (content type, caching rules, cookies, etc.)
3. **Body** - The actual content being sent (HTML, JSON, files, or empty)

Relic provides convenient constructors for common status codes, making it easy to create appropriate responses without memorizing HTTP status codes.

## Creating Responses

### Success Responses

Success responses (2xx status codes) indicate that the request was received, understood, and processed successfully.

#### 200 OK - Standard Success

The most common response indicates the request succeeded and returns the requested data:

```dart
router.get('/users/:id', (ctx) {
  final user = findUser(ctx.pathParameters[#id]);
  
  return ctx.respond(Response.ok(
    body: Body.fromString('User: ${user.name}'),
  ));
});
```

Use `Response.ok()` when:

- You've successfully retrieved data (GET requests)
- You've successfully processed data (POST/PUT requests)
- The operation completed without errors

#### 204 No Content - Success Without Body

When an operation succeeds but there's no content to return:

```dart
router.delete('/users/:id', (ctx) {
  deleteUser(ctx.pathParameters[#id]);
  
  // Success, but nothing to send back
  return ctx.respond(Response.noContent());
});
```

Use `Response.noContent()` when:

- Deleting a resource
- Updating a resource without returning it
- Performing an action that doesn't produce output

### Redirect Responses

Redirect responses (3xx status codes) tell the client that the requested resource has moved or that they should look elsewhere.

#### 301 Moved Permanently

Indicates a permanent URL change. Browsers and search engines will update their records:

```dart
router.get('/old-url', (ctx) {
  return ctx.respond(Response.movedPermanently(
    Uri.parse('/new-url'),
  ));
});
```

#### 302 Found - Temporary Redirect

Indicates a temporary URL change. The client should continue using the original URL for future requests:

```dart
router.get('/temporary', (ctx) {
  return ctx.respond(Response.found(
    Uri.parse('/current-location'),
  ));
});
```

#### 303 See Other

Commonly used after POST requests to redirect to a GET endpoint:

```dart
router.post('/submit-form', (ctx) async {
  // Process form submission...
  
  // Redirect to a success page
  return ctx.respond(Response.seeOther(
    Uri.parse('/success'),
  ));
});
```

This prevents form resubmission if the user refreshes their browser.

### Client Error Responses

Client error responses (4xx status codes) indicate that the request was invalid or cannot be fulfilled due to client-side issues.

#### 400 Bad Request

The request is malformed or contains invalid data:

```dart
router.post('/api/users', (ctx) async {
  final body = await ctx.request.readAsString();
  
  if (body.isEmpty) {
    return ctx.respond(Response.badRequest(
      body: Body.fromString('Request body is required'),
    ));
  }
  
  try {
    final data = jsonDecode(body);
    // Process data...
  } catch (e) {
    return ctx.respond(Response.badRequest(
      body: Body.fromString('Invalid JSON format'),
    ));
  }
});
```

Use `Response.badRequest()` when:

- Required parameters are missing
- Data format is invalid
- Validation fails

#### 401 Unauthorized

The client must authenticate before accessing the resource:

```dart
router.get('/dashboard', (ctx) {
  final auth = ctx.request.headers.authorization;
  
  if (auth == null) {
    return ctx.respond(Response.unauthorized(
      body: Body.fromString('Please log in to continue'),
    ));
  }
  
  // Validate credentials...
  return ctx.respond(Response.ok());
});
```

Use `Response.unauthorized()` when:

- Authentication is required but not provided
- Authentication credentials are invalid
- A session has expired

#### 403 Forbidden

The client is authenticated but doesn't have permission:

```dart
router.delete('/admin/users/:id', (ctx) {
  final user = getCurrentUser(ctx);
  
  if (!user.isAdmin) {
    return ctx.respond(Response.forbidden(
      body: Body.fromString('Admin privileges required'),
    ));
  }
  
  // Proceed with deletion...
  return ctx.respond(Response.ok());
});
```

Use `Response.forbidden()` when:

- The user is logged in but lacks necessary permissions
- Access to a resource is restricted by policy
- The operation violates business rules

#### 404 Not Found

The requested resource doesn't exist:

```dart
router.get('/users/:id', (ctx) {
  final id = ctx.pathParameters[#id];
  final user = findUser(id);
  
  if (user == null) {
    return ctx.respond(Response.notFound(
      body: Body.fromString('User not found'),
    ));
  }
  
  return ctx.respond(Response.ok(
    body: Body.fromString('User: ${user.name}'),
  ));
});
```

Use `Response.notFound()` when:

- A resource with the given ID doesn't exist
- A URL path doesn't match any route
- Data has been deleted or moved

### Server Error Responses

Server error responses (5xx status codes) indicate that the server encountered an error while processing a valid request.

#### 500 Internal Server Error

An unexpected error occurred on the server:

```dart
router.get('/data', (ctx) {
  try {
    final data = fetchData();
    return ctx.respond(Response.ok(
      body: Body.fromString(data),
    ));
  } catch (e) {
    // Log the error for debugging
    print('Error fetching data: $e');
    
    return ctx.respond(Response.internalServerError(
      body: Body.fromString('An error occurred. Please try again later.'),
    ));
  }
});
```

:::warning Security Notice

Never expose internal error details to clients in production. Log errors server-side and return generic error messages.

:::

#### 501 Not Implemented

The server doesn't support the requested functionality:

```dart
router.get('/beta-feature', (ctx) {
  return ctx.respond(Response.notImplemented(
    body: Body.fromString('This feature is coming soon'),
  ));
});
```

### Custom Status Codes

For status codes without a dedicated constructor, use the general `Response` constructor:

```dart
router.get('/teapot', (ctx) {
  return ctx.respond(Response(
    418,  // I'm a teapot
    body: Body.fromString('I refuse to brew coffee'),
  ));
});
```

## Working with Response Bodies

The response body contains the actual data you're sending to the client. Relic's `Body` class provides a unified way to handle different content types.

### Text Responses

For plain text responses, use `Body.fromString()`:

```dart
Response.ok(
  body: Body.fromString('Hello, World!'),
)
```

By default, Relic infers the MIME type from the content. For plain text, it sets `text/plain`.

### HTML Responses

To serve HTML content, specify the MIME type explicitly:

```dart
router.get('/page', (ctx) {
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

### JSON Responses

For JSON APIs, encode your data and specify the JSON MIME type:

```dart
import 'dart:convert';

router.get('/api/users/:id', (ctx) {
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

### Binary Data

For images, PDFs, or other binary content, use `Body.fromData()`:

```dart
import 'dart:typed_data';

router.get('/image.png', (ctx) {
  final imageBytes = Uint8List.fromList(loadImageData());
  
  return ctx.respond(Response.ok(
    body: Body.fromData(imageBytes),
  ));
});
```

Relic automatically infers the MIME type from the binary data when possible.

### Streaming Responses

For large files or generated content, stream the data instead of loading it all into memory:

```dart
router.get('/large-file', (ctx) {
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

### Empty Responses

Some responses don't need a body. Use `Body.empty()` or simply omit the body parameter:

```dart
// Explicitly empty
Response.ok(body: Body.empty())

// Or use noContent() which implies an empty body
Response.noContent()
```

## Setting Response Headers

Headers provide metadata about your response. Use the `Headers` class to build type-safe headers:

```dart
router.get('/api/data', (ctx) {
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

## Choosing the Right Status Code

Selecting the appropriate status code helps clients understand the outcome and take appropriate action:

### Quick Reference

#### 2xx - Success

- 200 OK - Request succeeded, returning data
- 204 No Content - Request succeeded, no data to return

#### 3xx - Redirection

- 301 Moved Permanently - Resource permanently moved
- 302 Found - Temporary redirect
- 303 See Other - Redirect after POST

#### 4xx - Client Errors

- 400 Bad Request - Invalid request format
- 401 Unauthorized - Authentication required
- 403 Forbidden - Insufficient permissions
- 404 Not Found - Resource doesn't exist

#### 5xx - Server Errors

- 500 Internal Server Error - Unexpected server error
- 501 Not Implemented - Feature not available

## Best Practices

### Always Provide Meaningful Error Messages

Help clients understand what went wrong and how to fix it:

```dart
// ❌ Not helpful
Response.badRequest(body: Body.fromString('Bad request'))

// ✅ Clear and actionable
Response.badRequest(
  body: Body.fromString('Missing required field: email'),
)
```

### Use Appropriate Status Codes

Match the status code to the actual situation:

```dart
// ❌ Wrong - returning 200 for errors
if (!user.exists) {
  return ctx.respond(Response.ok(
    body: Body.fromString('User not found'),
  ));
}

// ✅ Correct - use 404 for missing resources
if (!user.exists) {
  return ctx.respond(Response.notFound(
    body: Body.fromString('User not found'),
  ));
}
```

### Set Content-Type for Structured Data

Always specify the MIME type for JSON, XML, or HTML:

```dart
// ✅ Explicit content type
Response.ok(
  body: Body.fromString(jsonData, mimeType: MimeType.json),
)
```

### Handle Errors Gracefully

Catch exceptions and return appropriate error responses:

```dart
try {
  final result = performOperation();
  return ctx.respond(Response.ok(
    body: Body.fromString(result),
  ));
} catch (e) {
  print('Operation failed: $e');  // Log for debugging
  return ctx.respond(Response.internalServerError(
    body: Body.fromString('Operation failed'),
  ));
}
```

## Examples

- **[`requets_response_example.dart`](https://github.com/serverpod/relic/blob/main/example/requets_response_example.dart)** - Comprehensive example covering requests, responses, and advanced routing patterns

## Summary

Creating effective HTTP responses is crucial for building reliable web applications. Key takeaways:

- **Choose appropriate status codes** - 2xx for success, 3xx for redirects, 4xx for client errors, 5xx for server errors
- **Use Relic's response constructors** - `Response.ok()`, `Response.badRequest()`, `Response.notFound()`, etc.
- **Set proper content types** - specify `mimeType` for JSON, HTML, and other structured data
- **Include helpful error messages** - make them actionable and user-friendly
- **Handle exceptions gracefully** - catch errors and return appropriate 5xx responses
- **Use type-safe headers** - leverage `Headers.build()` for cache control, custom headers, etc.
- **Stream large content** - use `Body.fromDataStream()` for files and generated content

Remember: every handler must return a response. Make them meaningful, consistent, and helpful for your API consumers.
