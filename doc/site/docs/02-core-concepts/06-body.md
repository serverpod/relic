---
sidebar_position: 6
sidebar_label: Body
---

# Body

The Body system in Relic provides a powerful and flexible way to handle HTTP request and response bodies. It supports various content types, automatic MIME type detection, encoding handling, and efficient streaming for large payloads.

The `Body` class is the core component that represents the content of HTTP messages, designed to handle both small and large payloads efficiently through streaming, making it suitable for everything from simple text responses to large file uploads.

## Key features

The Body class offers several important capabilities that make it well-suited for modern web applications:

- **Stream-based architecture**: All body content is handled as `Stream<Uint8List>` for memory efficiency, allowing you to process large files without loading them entirely into memory
- **One-time read constraint**: Bodies can only be read once to prevent accidental double-consumption and ensure predictable behavior
- **Automatic type detection**: Intelligent MIME type inference for common formats like JSON, HTML, XML, and various binary file types
- **Encoding support**: Handles text encoding (UTF-8, Latin-1, etc.) automatically while allowing manual override when needed

## Creating bodies

### From string content

The most common way to create a body is from string content. Relic provides intelligent automatic detection of content types based on the string's structure, though you can always override this behavior when needed.

For simple text content, you can create a body directly from a string:

```dart
final body = Body.fromString('Hello, World!');
```

When you provide JSON content, Relic automatically detects the MIME type by analyzing the string structure:

```dart
final jsonBody = Body.fromString('{"message": "Hello"}');
// Automatically detects application/json MIME type
```

Similarly, HTML content is automatically recognized and tagged with the appropriate MIME type:

```dart
final htmlBody = Body.fromString('<!DOCTYPE html><html>...</html>');
// Automatically detects text/html MIME type
```

For cases where you need explicit control over the MIME type and encoding, you can specify these parameters directly:

```dart
final customBody = Body.fromString(
  'Custom content',
  mimeType: MimeType.plainText,
  encoding: latin1,
);
```

### From binary data

When working with binary content like images, documents, or other file types, you can create bodies from byte arrays. Relic includes sophisticated binary format detection that can identify many common file types by examining their magic bytes.

For binary data stored in a byte array, you can create a body that will automatically detect the file type:

```dart
final imageData = Uint8List.fromList([0x89, 0x50, 0x4E, 0x47, ...]);
final imageBody = Body.fromData(imageData);
// Automatically detects image/png from magic bytes
```

When automatic detection isn't suitable or you want to ensure a specific MIME type, you can explicitly specify it:

```dart
final binaryBody = Body.fromData(
  data,
  mimeType: MimeType.octetStream,
);
```

### From streams

For large files or data that arrives incrementally, you can create bodies from streams. This approach is memory-efficient and allows you to handle content that might be too large to fit in memory all at once.

When you have a stream of data and know its total size, it's recommended to provide the content length for better HTTP performance:

```dart
final streamBody = Body.fromDataStream(
  fileStream,
  mimeType: MimeType.pdf,
  contentLength: fileSize, // Optional but recommended
);
```

### Empty bodies

For HTTP responses that don't need to include any content (such as 204 No Content responses), you can create an empty body:

```dart
final emptyBody = Body.empty();
```

## Reading body content

Once you have a body, there are several ways to read its content depending on your needs. Remember that bodies can only be read once, so choose the appropriate method for your use case.

For direct access to the underlying byte stream, you can call the `read()` method. This gives you the raw data as it arrives:

```dart
final Stream<Uint8List> stream = body.read();
```

When working with text content in the context of a request or response message, you can use the convenient `readAsString()` method:

```dart
final String content = await request.readAsString();
```

If you need to decode the content using a specific encoding (different from what's specified in the Content-Type header), you can provide an encoding parameter:

```dart
final String content = await request.readAsString(latin1);
```

## Body types and encoding

The `BodyType` class is a fundamental component that combines MIME type and encoding information into a single, cohesive unit. This class is responsible for managing the content type metadata that gets translated into HTTP Content-Type headers.

The BodyType class encapsulates both the MIME type (what kind of content this is) and the optional encoding (how text content is encoded into bytes):

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

Relic includes intelligent MIME type detection that analyzes content to automatically determine the appropriate content type. This feature works for both text-based and binary content formats, saving you from having to manually specify types in most common scenarios.

#### Text content detection

For text-based content, Relic examines the structure and syntax to identify common formats. JSON content is detected by looking for characteristic opening braces or brackets:

```dart
Body.fromString('{"key": "value"}') // → application/json
Body.fromString('[1, 2, 3]')        // → application/json
```

HTML content is identified by recognizing standard HTML document declarations and opening tags:

```dart
Body.fromString('<!DOCTYPE html>...') // → text/html
Body.fromString('<html>...')          // → text/html
```

XML content is detected by looking for the standard XML processing instruction:

```dart
Body.fromString('<?xml version="1.0"?>...') // → application/xml
```

When content doesn't match any specific patterns, Relic falls back to plain text:

```dart
Body.fromString('Plain text') // → text/plain
```

#### Binary content detection

For binary content, Relic uses magic byte detection to identify file formats. This works by examining the first few bytes of the content, which contain format-specific signatures.

Common image formats are detected by their distinctive byte patterns:

```dart
final pngBytes = [0x89, 0x50, 0x4E, 0x47, ...];
Body.fromData(pngBytes) // → image/png

final jpegBytes = [0xFF, 0xD8, 0xFF, 0xE0, ...];
Body.fromData(jpegBytes) // → image/jpeg
```

Document formats like PDF are also recognized by their header signatures:

```dart
final pdfBytes = utf8.encode('%PDF-1.4...');
Body.fromData(pdfBytes) // → application/pdf
```

When the binary format cannot be determined, Relic defaults to the generic binary type:

```dart
Body.fromData(unknownBytes) // → application/octet-stream
```

### Encoding handling

Text content encoding is handled automatically by Relic, with sensible defaults that work for most use cases while still allowing you to override when necessary.

For text-based content types, Relic automatically applies UTF-8 encoding, which supports international characters and emojis:

```dart
final body = Body.fromString('Hello 🌍');
print(body.bodyType?.encoding); // utf8
```

When you need to use a different encoding (such as for legacy systems or specific requirements), you can specify it explicitly:

```dart
final latinBody = Body.fromString(
  'Café',
  encoding: latin1,
);
```

Binary content types don't have an encoding since they represent raw bytes rather than text:

```dart
final binaryBody = Body.fromData(imageBytes);
print(binaryBody.bodyType?.encoding); // null
```

## Content-length handling

Relic automatically calculates and tracks content length for bodies where the size is known in advance. This information is crucial for HTTP performance, as it allows clients and servers to optimize their handling of the content.

For string content, the length is calculated based on the encoded byte representation, not the character count:

```dart
final body = Body.fromString('Hello');
print(body.contentLength); // 5
```

When working with binary data from byte arrays, the length is simply the size of the array:

```dart
final data = Uint8List(1024);
final body = Body.fromData(data);
print(body.contentLength); // 1024
```

Empty bodies have a content length of zero, which is important for certain HTTP response types:

```dart
final empty = Body.empty();
print(empty.contentLength); // 0
```

### Streaming content

For content that arrives as a stream, the total length may not be known in advance. Relic handles both scenarios gracefully, optimizing HTTP transfer based on what information is available.

When you know the total size of streamed content, providing this information enables more efficient HTTP transfer:

```dart
final body = Body.fromDataStream(
  fileStream,
  contentLength: 1048576, // 1MB
);
```

For dynamic content where the size cannot be determined ahead of time, Relic will use chunked transfer encoding:

```dart
final body = Body.fromDataStream(
  dynamicStream,
  contentLength: null, // Will use chunked encoding
);
```

### Length in HTTP context

Within the context of handling HTTP requests and responses, you can easily check and work with content length information.

To determine if a request has any body content, you can check the `isEmpty` property:

```dart
if (request.isEmpty) {
  // Handle empty request body
}
```

For more detailed information about the body size, you can access the content length directly:

```dart
final length = request.body.contentLength;
if (length != null) {
  print('Body size: $length bytes');
} else {
  print('Streaming body with unknown size');
}
```

## Stream-based bodies

The stream-based architecture of Relic's Body class is designed to handle large content efficiently without consuming excessive memory. This approach allows you to process content incrementally, making it possible to handle files or data that are larger than available RAM.

When dealing with large file uploads or other substantial content, you can process the data chunk by chunk as it arrives:

```dart title="body_example.dart"
Future<ResponseContext> uploadHandler(NewContext ctx) async {
  final stream = ctx.request.read();
  
  await for (final chunk in stream) {
    // Process chunk by chunk
    await processChunk(chunk);
  }
  
  return ctx.respond(Response.ok());
}
```

### One-time read constraint

To ensure predictable behavior and prevent accidental data corruption, bodies enforce a one-time read constraint. Once you've started reading a body's content, attempting to read it again will result in an error.

This constraint helps prevent common programming errors and ensures that stream resources are properly managed:

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

When you need to read body content multiple times (such as in middleware that needs to inspect the content before passing it along), you can create a copy of the message with a fresh body.

This pattern is commonly used in middleware that needs to log or validate request content:

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

Building JSON APIs is a common use case where Relic's automatic content type detection and encoding handling shine. The framework automatically detects JSON content and sets appropriate headers.

Here's how to build a handler that processes JSON input and returns JSON output:

```dart title="body_example.dart"
Future<ResponseContext> jsonApiHandler(NewContext ctx) async {
  // Automatic JSON detection
  final jsonData = await ctx.request.readAsString();
  final data = jsonDecode(jsonData);
  
  // Process data...
  
  return ctx.respond(Response.ok(
    body: Body.fromString(
      jsonEncode({'result': 'success'}),
      mimeType: MimeType.json,
    ),
  ));
}
```

### File upload handler

When handling file uploads, you often need to validate file size and process content as a stream to avoid memory issues with large files. Relic's content-length handling makes this straightforward.

This example shows how to implement a file upload handler with size validation and streaming processing:

```dart title="body_example.dart"
Future<ResponseContext> fileUploadHandler(NewContext ctx) async {
  final contentLength = ctx.request.body.contentLength;
  
  if (contentLength != null && contentLength > maxFileSize) {
    return ctx.respond(Response.badRequest(
      body: Body.fromString('File too large'),
    ));
  }
  
  // Stream file to storage
  final stream = ctx.request.read();
  await saveStreamToFile(stream, 'uploads/file.bin');
  
  return ctx.respond(Response.ok(
    body: Body.fromString('Upload successful'),
  ));
}
```

### Image response

Serving static images or dynamically generated graphics is another common scenario where automatic MIME type detection proves valuable. Relic can automatically identify image formats and set appropriate Content-Type headers.

This handler demonstrates serving image files with automatic format detection:

```dart title="body_example.dart"
Future<ResponseContext> serveImageHandler(NewContext ctx) async {
  final imageBytes = await loadImageFile('logo.png');
  
  return ctx.respond(Response.ok(
    body: Body.fromData(imageBytes), // Auto-detects image/png
  ));
}
```

### Streaming response

For large datasets or real-time data generation, streaming responses allow you to start sending data before the entire response is ready. This improves perceived performance and reduces memory usage.

Here's an example of streaming a large dataset using chunked transfer encoding:

```dart title="body_example.dart"
Future<ResponseContext> streamDataHandler(NewContext ctx) async {
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
