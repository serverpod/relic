// ignore_for_file: avoid_log, prefer_final_parameters

import 'dart:async';
import 'dart:convert';
import 'dart:developer';
import 'dart:io';
import 'dart:typed_data';

import 'package:relic/io_adapter.dart';
import 'package:relic/relic.dart';

/// Comprehensive example demonstrating all Body class features from the documentation.
///
/// This example shows:
/// - Creating bodies from different content types
/// - Automatic MIME type detection
/// - Content-length handling
/// - Stream-based processing
/// - Practical handlers for common scenarios
Future<void> main() async {
  log('Starting Body example server...');

  // Setup router with various body handling examples
  final router = Router<Handler>()
    ..use('/', logRequests())
    ..get(
        '/',
        respondWith((final _) =>
            Response.ok(body: Body.fromString('Body example server'))))

    // Basic text response
    ..get(
        '/hello',
        respondWith(
            (final _) => Response.ok(body: Body.fromString('Hello, World!'))))

    // JSON API endpoint
    ..post('/api/data', jsonApiHandler)

    // File upload endpoint
    ..post('/upload', fileUploadHandler)

    // Image serving endpoint
    ..get('/image', serveImageHandler)

    // Streaming data endpoint
    ..get('/stream', streamDataHandler)

    // Body type detection examples
    ..get('/detect', bodyDetectionExamples)

    // Content length examples
    ..get('/length', contentLengthExamples)

    // Stream processing example
    ..post('/process-stream', streamProcessingHandler)

    // Body copying example (middleware)
    ..post(
        '/logged-echo',
        const Pipeline()
            .addMiddleware(loggingMiddleware)
            .addHandler(echoHandler))

    // Fallback for unknown routes
    ..fallback = respondWith((final _) => Response.notFound(
        body: Body.fromString("Sorry, that doesn't compute")));

  // Start the server
  await serve(router.asHandler, InternetAddress.loopbackIPv4, 8080);
  log('Server running on http://localhost:8080');
  log('Try these endpoints:');
  log('  GET  /hello - Simple text response');
  log('  POST /api/data - JSON API (send JSON data)');
  log('  POST /upload - File upload');
  log('  GET  /image - Image serving');
  log('  GET  /stream - Streaming response');
  log('  GET  /detect - MIME type detection examples');
  log('  GET  /length - Content length examples');
  log('  POST /process-stream - Stream processing');
  log('  POST /logged-echo - Body copying middleware');
}

/// JSON API handler demonstrating automatic JSON detection and processing.
Future<ResponseContext> jsonApiHandler(NewContext ctx) async {
  try {
    // Read and parse JSON input
    final jsonData = await ctx.request.readAsString();
    final data = jsonDecode(jsonData);

    log('Received JSON data: $data');

    // Process the data (example: add timestamp)
    final response = {
      'received': data,
      'timestamp': DateTime.now().toIso8601String(),
      'status': 'success'
    };

    // Return JSON response with automatic content type detection
    return ctx.respond(Response.ok(
      body: Body.fromString(
        jsonEncode(response),
        mimeType: MimeType.json,
      ),
    ));
  } catch (e) {
    return ctx.respond(Response.badRequest(
      body: Body.fromString('Invalid JSON: $e'),
    ));
  }
}

/// File upload handler with size validation and streaming processing.
Future<ResponseContext> fileUploadHandler(NewContext ctx) async {
  const maxFileSize = 10 * 1024 * 1024; // 10MB

  final contentLength = ctx.request.body.contentLength;

  // Validate file size
  if (contentLength != null && contentLength > maxFileSize) {
    return ctx.respond(Response.badRequest(
      body: Body.fromString(
          'File too large. Maximum size: ${maxFileSize ~/ 1024 ~/ 1024}MB'),
    ));
  }

  // Create upload directory if it doesn't exist
  final uploadDir = Directory('uploads');
  if (!uploadDir.existsSync()) {
    uploadDir.createSync();
  }

  // Generate unique filename
  final filename = 'upload_${DateTime.now().millisecondsSinceEpoch}.bin';
  final file = File('uploads/$filename');

  try {
    // Stream file to disk
    final stream = ctx.request.read();
    final sink = file.openWrite();

    var bytesWritten = 0;
    await for (final chunk in stream) {
      sink.add(chunk);
      bytesWritten += chunk.length;
    }

    await sink.close();

    log('File uploaded: $filename ($bytesWritten bytes)');

    return ctx.respond(Response.ok(
      body: Body.fromString(
        jsonEncode({
          'message': 'Upload successful',
          'filename': filename,
          'size': bytesWritten,
        }),
        mimeType: MimeType.json,
      ),
    ));
  } catch (e) {
    return ctx.respond(Response.internalServerError(
      body: Body.fromString('Upload failed: $e'),
    ));
  }
}

/// Image serving handler demonstrating automatic format detection.
Future<ResponseContext> serveImageHandler(NewContext ctx) async {
  // Create a simple PNG image (1x1 pixel red)
  final pngBytes = Uint8List.fromList([
    0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A, // PNG signature
    0x00, 0x00, 0x00, 0x0D, 0x49, 0x48, 0x44, 0x52, // IHDR chunk
    0x00, 0x00, 0x00, 0x01, 0x00, 0x00, 0x00, 0x01, // 1x1 dimensions
    0x08, 0x02, 0x00, 0x00, 0x00, 0x90, 0x77, 0x53,
    0xDE, 0x00, 0x00, 0x00, 0x0C, 0x49, 0x44, 0x41, // IDAT chunk
    0x54, 0x08, 0xD7, 0x63, 0xF8, 0x0F, 0x00, 0x00,
    0x01, 0x00, 0x01, 0x5C, 0xC2, 0xD2, 0x3D, 0x00,
    0x00, 0x00, 0x00, 0x49, 0x45, 0x4E, 0x44, 0xAE, // IEND chunk
    0x42, 0x60, 0x82
  ]);

  // Body automatically detects image/png from magic bytes
  return ctx.respond(Response.ok(
    body: Body.fromData(pngBytes),
  ));
}

/// Streaming response handler for large datasets.
Future<ResponseContext> streamDataHandler(NewContext ctx) async {
  // Create a stream that generates data incrementally
  final dataStream = generateLargeDataset();

  return ctx.respond(Response.ok(
    body: Body.fromDataStream(
      dataStream,
      mimeType: MimeType.json,
      // contentLength omitted for chunked encoding
    ),
  ));
}

/// Generates a stream of JSON data to demonstrate streaming responses.
Stream<Uint8List> generateLargeDataset() async* {
  yield utf8.encode('{"items": [');

  for (int i = 0; i < 500; i++) {
    final item = jsonEncode({
      'id': i,
      'name': 'Item $i',
      'timestamp': DateTime.now().toIso8601String(),
    });

    if (i > 0) yield utf8.encode(',');
    yield utf8.encode(item);

    // Simulate processing delay
    await Future<void>.delayed(const Duration(milliseconds: 10));
  }

  yield utf8.encode(']}');
}

/// Handler demonstrating MIME type detection examples.
Future<ResponseContext> bodyDetectionExamples(NewContext ctx) async {
  final examples = <String, String>{};

  // JSON detection
  final jsonBody = Body.fromString('{"key": "value"}');
  examples['JSON detection'] = jsonBody.bodyType?.mimeType.toString() ?? 'null';

  // HTML detection
  final htmlBody =
      Body.fromString('<!DOCTYPE html><html><body>Hello</body></html>');
  examples['HTML detection'] = htmlBody.bodyType?.mimeType.toString() ?? 'null';

  // XML detection
  final xmlBody = Body.fromString('<?xml version="1.0"?><root></root>');
  examples['XML detection'] = xmlBody.bodyType?.mimeType.toString() ?? 'null';

  // Plain text fallback
  final textBody = Body.fromString('Just some plain text');
  examples['Plain text fallback'] =
      textBody.bodyType?.mimeType.toString() ?? 'null';

  // Binary detection (PNG)
  final pngBytes =
      Uint8List.fromList([0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A]);
  final pngBody = Body.fromData(pngBytes);
  examples['PNG detection'] = pngBody.bodyType?.mimeType.toString() ?? 'null';

  return ctx.respond(Response.ok(
    body: Body.fromString(
      jsonEncode({
        'title': 'MIME Type Detection Examples',
        'examples': examples,
      }),
      mimeType: MimeType.json,
    ),
  ));
}

/// Handler demonstrating content length handling.
Future<ResponseContext> contentLengthExamples(NewContext ctx) async {
  final examples = <String, dynamic>{};

  // String content length
  final stringBody = Body.fromString('Hello');
  examples['String body length'] = stringBody.contentLength;

  // Binary data length
  final binaryData = Uint8List(1024);
  final binaryBody = Body.fromData(binaryData);
  examples['Binary body length'] = binaryBody.contentLength;

  // Empty body length
  final emptyBody = Body.empty();
  examples['Empty body length'] = emptyBody.contentLength;

  // UTF-8 encoding affects length
  final unicodeBody = Body.fromString('Hello 🌍');
  examples['Unicode body length'] = unicodeBody.contentLength;
  examples['Unicode character count'] = 'Hello 🌍'.length;

  return ctx.respond(Response.ok(
    body: Body.fromString(
      jsonEncode({
        'title': 'Content Length Examples',
        'examples': examples,
        'note': 'Length is in bytes, not characters',
      }),
      mimeType: MimeType.json,
    ),
  ));
}

/// Handler demonstrating stream processing for large uploads.
Future<ResponseContext> streamProcessingHandler(NewContext ctx) async {
  var totalBytes = 0;
  var chunkCount = 0;

  try {
    final stream = ctx.request.read();

    await for (final chunk in stream) {
      totalBytes += chunk.length;
      chunkCount++;

      // Process chunk (example: just count bytes)
      log('Processed chunk $chunkCount: ${chunk.length} bytes');
    }

    return ctx.respond(Response.ok(
      body: Body.fromString(
        jsonEncode({
          'message': 'Stream processed successfully',
          'totalBytes': totalBytes,
          'chunkCount': chunkCount,
        }),
        mimeType: MimeType.json,
      ),
    ));
  } catch (e) {
    return ctx.respond(Response.internalServerError(
      body: Body.fromString('Stream processing failed: $e'),
    ));
  }
}

/// Middleware demonstrating body copying for multiple reads.
Middleware loggingMiddleware = (Handler next) {
  return (ctx) async {
    // Read body content for logging
    final content = await ctx.request.readAsString();
    log('Request body: $content');

    // Create new request with fresh body
    final newRequest = ctx.request.copyWith(
      body: Body.fromString(content),
    );

    // Continue with new request
    return next(ctx.withRequest(newRequest));
  };
};

/// Simple echo handler that returns the request body.
Future<ResponseContext> echoHandler(NewContext ctx) async {
  final content = await ctx.request.readAsString();

  return ctx.respond(Response.ok(
    body: Body.fromString(
      jsonEncode({
        'echo': content,
        'contentType': ctx.request.mimeType?.toString(),
        'encoding': ctx.request.encoding?.name,
      }),
      mimeType: MimeType.json,
    ),
  ));
}
