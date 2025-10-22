---
sidebar_position: 6
sidebar_label: Body
---

# Body

The Body system in Relic provides a powerful and flexible way to handle HTTP request and response bodies. It supports various content types, automatic MIME type detection, encoding handling, and efficient streaming for large payloads.

The `Body` class represents the content of HTTP messages, designed to handle both small and large payloads efficiently through streaming.

## Key features

- Stream-based architecture: All body content is handled as `Stream<Uint8List>` for memory efficiency, allowing you to process large files without loading them entirely into memory
- One-time read constraint: Bodies can only be read once to prevent accidental double-consumption
- Automatic type detection: Intelligent MIME type inference for JSON, HTML, XML, and binary file types
- Encoding support: Handles text encoding (UTF-8, Latin-1, etc.) automatically with manual override options

## Creating bodies

### From string content

The most common way to create a body is from string content, and Relic can infer content types from the structure of the text you provide. This lets you write straightforward handlers while still getting correct headers and encodings without extra work.

For simple text content, create a body directly from a string and return it as part of your response. Relic will handle encoding and set a sensible default content type for you:

```dart
final body = Body.fromString('Hello, World!');
```

For JSON content, Relic detects the MIME type based on the shape of the string. You can return JSON without manually setting headers, which keeps handlers concise and clear:

```dart
final jsonBody = Body.fromString('{"message": "Hello"}');
// Automatically detects application/json
```

HTML can be treated the same way, with automatic detection ensuring that browsers and clients receive the correct content type. This reduces the need to repeat metadata that Relic can determine on your behalf:

```dart
final htmlBody = Body.fromString('<!DOCTYPE html><html>...</html>');
// Automatically detects text/html
```

When you need explicit control, specify the MIME type and encoding directly. This is useful for legacy encodings, strict APIs, or any time you want to override detection for clarity or compliance:

```dart
final customBody = Body.fromString(
  'Héllo world',
  mimeType: MimeType.plainText,
  encoding: latin1,
);
```

### From files

Serving files efficiently often depends on the file size and how you plan to deliver the content. You can read files fully into memory for smaller assets, or stream them for large or unknown sizes to keep memory usage predictable.

For small to medium files, read the entire file into memory and wrap the bytes in a body. This approach is simple and works well for assets like text files and small images:

```dart
final file = File('example.txt');
final bytes = await file.readAsBytes();
final body = Body.fromData(bytes);
```

When you know a file is binary or want to enforce a specific type, you can set the MIME type explicitly. This can help when serving files with uncommon formats or when autodetection is not desirable:

```dart
final binaryBody = Body.fromData(
  data,
  mimeType: MimeType.octetStream,
);
```

For large files or data that arrives incrementally, prefer streaming to avoid excessive memory usage. Streaming lets clients start receiving data immediately and keeps your server responsive under load:

```dart
final file = File('large-file.dat');
final fileStream = file.openRead();
final fileSize = await file.length();

final streamBody = Body.fromDataStream(
  fileStream,
  contentLength: fileSize, // Optional but recommended
);
```

### Empty bodies

Some responses should not include content, such as those with status 204. In these cases, create an empty body to make your intent explicit and allow Relic to set the appropriate headers:

```dart
final emptyBody = Body.empty();
```

## Reading body content

Bodies can only be read once, so choose the most appropriate method for your scenario and avoid multiple reads of the same stream. This constraint prevents subtle bugs and ensures handlers operate in a predictable way.

If you need direct access to the bytes, read the underlying stream and process chunks as they arrive. This is useful for custom parsers or streaming transformations:

```dart
final Stream<Uint8List> stream = body.read();
```

When working with request or response bodies that contain text, read the content as a string to get a decoded value. This method handles common cases where payloads are JSON or plain text:

```dart
final String content = await ctx.request.readAsString();
```

If a specific character encoding is required, pass it explicitly to the read method. This gives you full control when interacting with systems that do not use UTF-8:

```dart
final String content = await ctx.request.readAsString(latin1);
```

## Body types and encoding

The `BodyType` class combines MIME type and encoding information to produce the Content-Type header value. By centralizing this logic, Relic keeps handlers clean and avoids duplicated header formatting throughout your code:

```dart
class BodyType {
  final MimeType mimeType;
  final Encoding? encoding;

  // Generates Content-Type header value
  String toHeaderValue() {
    if (encoding != null) {
      return '${mimeType.toHeaderValue()}; charset=${encoding!.name}';
    }
    return mimeType.toHeaderValue();
  }
}
```

### MIME type detection

Relic analyzes content to determine the appropriate content type for both text and binary formats. This detection reduces boilerplate in handlers and helps ensure clients interpret responses correctly.

#### Text content detection

JSON is detected by typical structural markers like braces and brackets, so you can return JSON strings and let Relic set the proper MIME type. This keeps your code focused on business logic instead of metadata:

```dart
Body.fromString('{"key": "value"}') // → application/json
Body.fromString('[1, 2, 3]')        // → application/json
```

HTML is recognized by standard declarations and tags, which means simple templated content or static pages can be returned with minimal setup. Detection ensures browsers render the content as expected:

```dart
Body.fromString('<!DOCTYPE html>...') // → text/html
Body.fromString('<html>...')          // → text/html
```

XML is identified by the processing instruction at the start of the document, allowing you to return XML without hand-writing headers. This is particularly helpful for integrations that still rely on XML:

```dart
Body.fromString('<?xml version="1.0"?>...') // → application/xml
```

Other text defaults to plain text, which provides a safe and predictable fallback. You can always override the type if you need a more specific value:

```dart
Body.fromString('Plain text') // → text/plain
```

#### Binary content detection

Relic uses magic byte detection for common binary formats, which means files like images and PDFs often get the correct type automatically. This improves client compatibility and reduces manual configuration:

```dart
final pngBytes = [0x89, 0x50, 0x4E, 0x47, ...];
Body.fromData(pngBytes) // → image/png

final jpegBytes = [0xFF, 0xD8, 0xFF, 0xE0, ...];
Body.fromData(jpegBytes) // → image/jpeg
```

Document formats, such as PDF, are also recognized by their signatures. This allows you to serve documents confidently without hard-coding content types in most cases:

```dart
final pdfBytes = utf8.encode('%PDF-1.4...');
Body.fromData(pdfBytes) // → application/pdf
```

If a format is not recognized, Relic falls back to a generic binary type. This conservative default ensures downloads still work even when the type is unknown:

```dart
Body.fromData(unknownBytes) // → application/octet-stream
```

### Encoding handling

Text encodings are handled automatically with sensible defaults, which simplifies working with modern UTF-8 workflows. When needed, you can specify a different encoding to interoperate with systems that expect other character sets:

```dart
final body = Body.fromString('Hello 🌍');
print(body.bodyType?.encoding); // utf8
```

If you must use a different character set, set the encoding explicitly. This keeps your intent clear and ensures the Content-Type header reflects the actual encoding used:

```dart
final latinBody = Body.fromString(
  'Café',
  encoding: latin1,
);
```

Binary content does not use a character encoding, so the encoding field is absent. This distinction helps prevent accidental misinterpretation of raw bytes as text:

```dart
final binaryBody = Body.fromData(imageBytes);
print(binaryBody.bodyType?.encoding); // null
```

## Content-length handling

Relic calculates and tracks content length when it is known, which helps clients make efficient decisions about buffering and progress reporting. Providing accurate sizes improves performance and can reduce latency for some clients.

For string content, the reported length reflects the number of encoded bytes rather than characters. This distinction matters for non-ASCII text and ensures the header value matches the transmitted payload:

```dart
final body = Body.fromString('Hello');
print(body.contentLength); // 5
```

For binary data, the content length is simply the number of bytes in the buffer. This is straightforward for in-memory data and allows the server to send a precise Content-Length header:

```dart
final data = Uint8List(1024);
final body = Body.fromData(data);
print(body.contentLength); // 1024
```

Empty bodies report a length of zero, making it explicit that there is no content to read. This can be useful when checking preconditions or responding with status codes that must not include a body:

```dart
final empty = Body.empty();
print(empty.contentLength); // 0
```

### Streaming content

When streaming, the total size may not be known before transmission begins. If you do know the size, provide it so Relic can send a Content-Length header, which allows some clients to optimize downloads:

```dart
final file = File('large-file.dat');
final fileStream = file.openRead();
final fileSize = await file.length();

final body = Body.fromDataStream(
  fileStream,
  contentLength: fileSize,
);
```

If the size is unknown, Relic will use chunked transfer encoding so that data can start flowing immediately. This is ideal for generated content or pipelines that produce output over time:

```dart
final body = Body.fromDataStream(
  dynamicStream,
  contentLength: null, // Will use chunked encoding
);
```

### Length in HTTP context

You can quickly determine whether a request includes a body, which helps you make early decisions in handlers and return helpful errors for missing input. This check avoids unnecessary reads when there is nothing to read:

```dart
if (request.isEmpty) {
  // Handle empty request body
}
```

It is also useful to inspect the content length directly when validating uploads or applying limits. If a length is present, you can enforce thresholds before reading any data, and if not, you can switch to streaming-safe logic:

```dart
final length = request.body.contentLength;
if (length != null) {
  print('Body size: $length bytes');
} else {
  print('Streaming body with unknown size');
}
```

## Stream-based bodies

Relic’s stream-based approach makes it practical to handle large payloads without exhausting memory, since data is processed incrementally. This pattern is especially helpful for uploads and transformations that work chunk by chunk:

```dart title="body_example.dart"
/// File upload handler with size validation
Future<ResponseContext> uploadHandler(NewContext ctx) async {
  const maxFileSize = 10 * 1024 * 1024; // 10MB
  final contentLength = ctx.request.body.contentLength;

  if (contentLength != null && contentLength > maxFileSize) {
    return ctx.respond(Response.badRequest(
      body: Body.fromString('File too large'),
    ));
  }

  final stream = ctx.request.read();
  final file = File('uploads/file.bin');
  await file.parent.create(recursive: true);
  await stream.forEach((chunk) => file.openWrite().write(chunk));

  return ctx.respond(Response.ok(
    body: Body.fromString('Upload successful'),
  ));
}
```

### One-time read constraint

To keep processing predictable and avoid subtle bugs, bodies enforce a one-time read rule. Once a body’s stream has been consumed, subsequent reads throw an error, which makes improper use immediately visible during development:

```dart title="body_example.dart"
final body = Body.fromString('test');

// First read - OK
final stream1 = body.read();

// Second read - throws StateError
try {
  final stream2 = body.read(); // ❌ Error!
} catch (e) {
  print(e); // "The 'read' method can only be called once"
}
```

### Copying bodies

If you need to inspect content in middleware and still pass it along to downstream handlers, create a new message with a fresh body. This pattern preserves the one-time read rule while allowing logging or validation before the main handler runs:

```dart title="body_example.dart"
Middleware loggingMiddleware(Handler next) {
  return (ctx) async {
    // Read body content
    final content = await ctx.request.readAsString();

    // Create new request with fresh body
    final newRequest = ctx.request.copyWith(
      body: Body.fromString(content),
    );

    // Continue with new request
    return next(ctx.withRequest(newRequest));
  };
}
```

## Practical examples

### JSON API handler

This example reads JSON input from the request, logs it for observability, and returns a JSON response. The body helper detects JSON automatically, and the explicit MIME type makes the intent clear to both clients and maintainers:

```dart title="body_example.dart"
/// JSON API handler
Future<ResponseContext> apiDataHandler(NewContext ctx) async {
  final jsonData = await ctx.request.readAsString();
  final data = jsonDecode(jsonData);

  log('Received: $data');

  return ctx.respond(Response.ok(
    body: Body.fromString(
      jsonEncode({'result': 'success'}),
      mimeType: MimeType.json,
    ),
  ));
}
```

### File upload handler

This handler validates the upload size before reading the stream, then writes the content directly to disk. Streaming avoids buffering the entire file in memory and keeps the server responsive under heavy load:

```dart title="body_example.dart"
/// File upload handler with size validation
Future<ResponseContext> uploadHandler(NewContext ctx) async {
  const maxFileSize = 10 * 1024 * 1024; // 10MB
  final contentLength = ctx.request.body.contentLength;

  if (contentLength != null && contentLength > maxFileSize) {
    return ctx.respond(Response.badRequest(
      body: Body.fromString('File too large'),
    ));
  }

  final stream = ctx.request.read();
  final file = File('uploads/file.bin');
  await file.parent.create(recursive: true);
  await stream.forEach((chunk) => file.openWrite().write(chunk));

  return ctx.respond(Response.ok(
    body: Body.fromString('Upload successful'),
  ));
}
```

### Image response

Here the server reads an SVG file from disk and returns it as binary data. The SVG type must be set explicitly with `MimeType.parse('image/svg+xml')` so clients receive the correct Content-Type.

```dart title="body_example.dart"
Future<ResponseContext> imageHandler(NewContext ctx) async {
  final file = File('example/static_files/logo.svg');
  final imageBytes = await file.readAsBytes();

  return ctx.respond(Response.ok(
    body: Body.fromData(
      imageBytes,
      mimeType: MimeType.parse('image/svg+xml'),
    ),
  ));
}
```

### Streaming response

This endpoint produces a stream of JSON lines to demonstrate chunked transfer encoding. Clients can start processing data as soon as it becomes available, which is useful for progress updates and long-running computations:

```dart title="body_example.dart"
/// Streaming response handler with chunked transfer encoding
Future<ResponseContext> streamHandler(NewContext ctx) async {
  Stream<Uint8List> generateLargeDataset() async* {
    for (var i = 0; i < 100; i++) {
      await Future.delayed(Duration(milliseconds: 50));
      yield utf8.encode('{"item": $i}\n');
    }
  }

  final dataStream = generateLargeDataset();

  return ctx.respond(Response.ok(
    body: Body.fromDataStream(
      dataStream,
      mimeType: MimeType.json,
      // contentLength omitted for chunked encoding
    ),
  ));
}
```
