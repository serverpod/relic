import 'dart:convert';
import 'dart:developer';
import 'dart:io';
import 'dart:typed_data';

import 'package:relic/relic.dart';

/// Example demonstrating Body class features. Shows creating bodies from
/// strings, files, and streams.
Future<void> main() async {
  final app = RelicApp()
    ..fallback = (final req) {
      return Response.ok(body: Body.fromString('Body Example'));
    };

  // Simple text response endpoint.
  app.get('/hello', helloHandler);

  // JSON response with automatic content-type detection.
  app.get('/data', dataHandler);

  // Serve small files by loading them entirely into memory.
  app.get('/file/small', smallFileHandler);

  // Stream large files to avoid memory issues.
  app.get('/file/large', largeFileHandler);

  // Echo endpoint that reads and returns the request body.
  app.post('/echo', echoHandler);

  // API endpoint that processes JSON requests.
  app.post('/api/data', apiDataHandler);

  // File upload endpoint with size limits.
  app.post('/upload', uploadHandler);

  // Serve images with proper content-type headers.
  app.get('/image', imageHandler);

  // Stream data using chunked transfer encoding.
  app.get('/stream', streamHandler);

  // Serve static files from a directory with caching.
  app.anyOf(
    {Method.get, Method.head},
    '/static/**',
    StaticHandler.directory(
      Directory('example/_static_files'),
      cacheControl: (_, _) => CacheControlHeader(maxAge: 3600),
    ).asHandler,
  );

  // Serve a single static file with custom cache settings.
  app.get(
    '/logo',
    StaticHandler.file(
      File('example/_static_files/logo.svg'),
      cacheControl: (_, _) => CacheControlHeader(maxAge: 86400),
    ).asHandler,
  );

  await app.serve();
  log('Server running on http://localhost:8080');
  log('Try these endpoints:');
  log('  GET  /hello - Basic text response');
  log('  GET  /data - JSON with auto-detection');
  log('  GET  /file/small - Serve small file');
  log('  GET  /file/large - Stream large file');
  log('  POST /echo - Echo request body');
  log('  POST /api/data - JSON API handler');
  log('  POST /upload - File upload with validation');
  log('  GET  /image - Serve SVG image');
  log('  GET  /stream - Streaming response');
  log('  GET  /static/** - Static files in a directory');
  log('  GET  /logo - Single static file');
}

/// Returns a simple text response.
Response helloHandler(final Request req) {
  return Response.ok(body: Body.fromString('Hello, World!'));
}

/// Returns JSON with automatic content-type detection.
Response dataHandler(final Request req) {
  return Response.ok(
    body: Body.fromString('{"message": "Hello"}'),
    // Content-type is automatically detected as application/json.
  );
}

/// Serves small files by loading them entirely into memory.
Future<Response> smallFileHandler(final Request req) async {
  final file = File('example.txt');

  if (!await file.exists()) {
    await file.writeAsString('This is a small example file.');
  }

  final bytes = await file.readAsBytes();

  return Response.ok(body: Body.fromData(bytes));
}

/// Streams large files to avoid memory issues.
Future<Response> largeFileHandler(final Request req) async {
  final file = File('large-file.dat');

  if (!await file.exists()) {
    final sink = file.openWrite();
    for (var i = 0; i < 10000; i++) {
      sink.write('This is line $i of a large file.\n');
    }
    await sink.close();
  }

  final fileStream = file.openRead().map((final e) => Uint8List.fromList(e));
  final fileSize = await file.length();

  return Response.ok(
    body: Body.fromDataStream(fileStream, contentLength: fileSize),
  );
}

/// Echoes the request body back as a response.
Future<Response> echoHandler(final Request req) async {
  final content = await req.readAsString();

  return Response.ok(body: Body.fromString('You sent: $content'));
}

/// Processes JSON requests and returns structured responses.
// doctag<body-json-api-handler>
Future<Response> apiDataHandler(final Request req) async {
  final jsonData = await req.readAsString();
  final data = jsonDecode(jsonData);

  log('Received: $data');

  return Response.ok(
    body: Body.fromString(
      jsonEncode({'result': 'success'}),
      mimeType: MimeType.json,
    ),
  );
}
// end:doctag<body-json-api-handler>

/// Handles file uploads with size validation and streaming.
// doctag<body-upload-validate-size>
Future<Response> uploadHandler(final Request req) async {
  // Limit uploads to 10 MB.
  const maxFileSize = 10 * 1024 * 1024;

  final file = File('uploads/file.bin');
  await file.create(recursive: true);
  final sink = file.openWrite();
  try {
    // Use maxLength to enforce the size limit across all chunks.
    // This works correctly even when content-length is unknown (chunked encoding).
    await sink.addStream(req.read(maxLength: maxFileSize));
  } on MaxBodySizeExceeded {
    return Response.badRequest(body: Body.fromString('File too large'));
  } finally {
    await sink.close();
  }

  return Response.ok(body: Body.fromString('Upload successful'));
}
// end:doctag<body-upload-validate-size>

/// Serves images with proper content-type headers.
// doctag<body-image-auto-format>
Future<Response> imageHandler(final Request req) async {
  final file = File('example/_static_files/logo.svg');
  final imageBytes = await file.readAsBytes();

  return Response.ok(
    body: Body.fromData(imageBytes, mimeType: MimeType.parse('image/svg+xml')),
  );
}
// end:doctag<body-image-auto-format>

/// Demonstrates streaming responses with chunked encoding.
// doctag<body-streaming-chunked>
Future<Response> streamHandler(final Request req) async {
  Stream<Uint8List> generateLargeDataset() async* {
    for (var i = 0; i < 100; i++) {
      await Future<void>.delayed(const Duration(milliseconds: 50));

      // Yield individual chunks for streaming.
      yield utf8.encode('{"item": $i}\n');
    }
  }

  final dataStream = generateLargeDataset();

  return Response.ok(
    body: Body.fromDataStream(
      dataStream,
      mimeType: MimeType.json,
      // Omit contentLength to enable chunked transfer encoding.
    ),
  );
}

// end:doctag<body-streaming-chunked>
