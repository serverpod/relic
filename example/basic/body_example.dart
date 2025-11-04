import 'dart:convert';
import 'dart:developer';
import 'dart:io';
import 'dart:typed_data';

import 'package:relic/io_adapter.dart';
import 'package:relic/relic.dart';

/// Example demonstrating Body class features.
/// Shows creating bodies from strings, files, and streams.
Future<void> main() async {
  final app =
      RelicApp()
        ..fallback = (final req) {
          return Response.ok(body: Body.fromString('Body Example'));
        };

  // Basic text response
  app.get('/hello', helloHandler);

  // JSON with automatic MIME detection
  app.get('/data', dataHandler);

  // Small file - read entire file into memory
  app.get('/file/small', smallFileHandler);

  // Large file - stream for memory efficiency
  app.get('/file/large', largeFileHandler);

  // Reading request body as string
  app.post('/echo', echoHandler);

  // JSON API handler
  app.post('/api/data', apiDataHandler);

  // File upload handler with size validation
  app.post('/upload', uploadHandler);

  // Image response with automatic format detection
  app.get('/image', imageHandler);

  // Streaming response with chunked transfer encoding
  app.get('/stream', streamHandler);

  // Static file serving with directory handler
  app.anyOf(
    {Method.get, Method.head},
    '/static/**',
    StaticHandler.directory(
      Directory('example/static_files'),
      cacheControl: (_, _) => CacheControlHeader(maxAge: 3600),
    ).asHandler,
  );

  // Single static file serving
  app.get(
    '/logo',
    StaticHandler.file(
      File('example/static_files/logo.svg'),
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

/// Basic text response handler
Response helloHandler(final Request req) {
  return Response.ok(body: Body.fromString('Hello, World!'));
}

/// JSON with automatic MIME detection handler
Response dataHandler(final Request req) {
  return Response.ok(
    body: Body.fromString('{"message": "Hello"}'),
    // Automatically detects application/json
  );
}

/// Small file handler - read entire file into memory
Future<Response> smallFileHandler(final Request req) async {
  final file = File('example.txt');

  if (!await file.exists()) {
    await file.writeAsString('This is a small example file.');
  }

  final bytes = await file.readAsBytes();

  return Response.ok(body: Body.fromData(bytes));
}

/// Large file handler - stream for memory efficiency
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

/// Reading request body as string handler
Future<Response> echoHandler(final Request req) async {
  final content = await req.readAsString();

  return Response.ok(body: Body.fromString('You sent: $content'));
}

/// JSON API handler
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

/// File upload handler with size validation
Future<Response> uploadHandler(final Request req) async {
  const maxFileSize = 10 * 1024 * 1024; // 10MB
  final contentLength = req.body.contentLength;

  if (contentLength != null && contentLength > maxFileSize) {
    return Response.badRequest(body: Body.fromString('File too large'));
  }

  final file = File('uploads/file.bin');
  await file.create(recursive: true);
  final sink = file.openWrite();
  try {
    await sink.addStream(req.read());
  } finally {
    await sink.close();
  }

  return Response.ok(body: Body.fromString('Upload successful'));
}

/// Image response handler with automatic format detection
Future<Response> imageHandler(final Request req) async {
  final file = File('example/static_files/logo.svg');
  final imageBytes = await file.readAsBytes();

  return Response.ok(
    body: Body.fromData(imageBytes, mimeType: MimeType.parse('image/svg+xml')),
  );
}

/// Streaming response handler with chunked transfer encoding
Future<Response> streamHandler(final Request req) async {
  Stream<Uint8List> generateLargeDataset() async* {
    for (var i = 0; i < 100; i++) {
      await Future<void>.delayed(const Duration(milliseconds: 50));
      yield utf8.encode('{"item": $i}\n'); // Changed from yield* to yield
    }
  }

  final dataStream = generateLargeDataset();

  return Response.ok(
    body: Body.fromDataStream(
      dataStream,
      mimeType: MimeType.json,
      // contentLength omitted for chunked encoding
    ),
  );
}
