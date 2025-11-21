import 'dart:convert';
import 'dart:developer';
import 'dart:typed_data';
import 'package:relic/io_adapter.dart';
import 'package:relic/relic.dart';

// Consolidated examples from requests.md and responses.md.
// This file demonstrates complete request-response cycles.
Future<void> main() async {
  final app = RelicApp();

  // Demonstrate accessing HTTP method information.
  // doctag<basic-request-response>
  app.get('/info', (final req) {
    final method = req.method; // Method.get
    return Response.ok(
      body: Body.fromString('Received a ${method.name} request'),
    );
  });
  // end:doctag<basic-request-response>

  // Extract and use path parameters from URLs.
  // doctag<path-params-complete>
  app.get('/users/:id', (final req) {
    final id = req.pathParameters[#id]!;
    final matchedPath = req.matchedPath;
    final fullUri = req.url;

    log('Matched path: $matchedPath, id: $id');
    log('Full URI: $fullUri');

    // Create a mock user object for the response and return it as JSON.
    final user = {
      'id': int.tryParse(id),
      'name': 'User $id',
      'email': 'user$id@example.com',
    };

    return Response.ok(
      body: Body.fromString(jsonEncode(user), mimeType: MimeType.json),
    );
  });
  // end:doctag<path-params-complete>

  // Handle single-value query parameters with validation.
  // doctag<query-params-complete>
  app.get('/search', (final req) {
    final query = req.url.queryParameters['query'];
    final page = req.url.queryParameters['page'];

    if (query == null) {
      return Response.badRequest(
        body: Body.fromString('Query parameter "query" is required'),
      );
    }

    final pageNum = int.tryParse(page ?? '1') ?? 1;
    final results = {
      'query': query,
      'page': pageNum,
      'results': ['Result 1', 'Result 2', 'Result 3'],
    };

    return Response.ok(
      body: Body.fromString(jsonEncode(results), mimeType: MimeType.json),
    );
  });
  // end:doctag<query-params-complete>

  // Process multiple values for the same query parameter.
  // doctag<query-multi-complete>
  app.get('/filter', (final req) {
    final tags = req.url.queryParametersAll['tag'] ?? [];
    final results = {
      'tags': tags,
      'filtered_items':
          tags.map((final tag) => 'Item tagged with $tag').toList(),
    };

    return Response.ok(
      body: Body.fromString(jsonEncode(results), mimeType: MimeType.json),
    );
  });
  // end:doctag<query-multi-complete>

  // Access headers using type-safe methods.
  // doctag<headers-complete>
  app.get('/headers-info', (final req) {
    final request = req;

    // Get typed header values.
    final mimeType = request.mimeType; // MimeType? (from Content-Type)
    final userAgent = request.headers.userAgent; // String?
    final contentLength = request.headers.contentLength; // int?

    final info = {
      'browser': userAgent ?? 'Unknown',
      'content_type': mimeType?.toString() ?? 'None',
      'content_length': contentLength ?? 0,
    };

    return Response.ok(
      body: Body.fromString(jsonEncode(info), mimeType: MimeType.json),
    );
  });
  // end:doctag<headers-complete>

  // Handle different types of authorization headers.
  // doctag<auth-complete>
  app.get('/protected', (final req) {
    final auth = req.headers.authorization;

    if (auth is BearerAuthorizationHeader) {
      final token = auth.token;
      // In a real application, validate the token here.
      return Response.ok(
        body: Body.fromString(
          jsonEncode({
            'message': 'Access granted',
            'token_length': token.length,
          }),
          mimeType: MimeType.json,
        ),
      );
    } else if (auth is BasicAuthorizationHeader) {
      final username = auth.username;
      // In a real application, validate the credentials here.
      return Response.ok(
        body: Body.fromString(
          jsonEncode({'message': 'Basic auth received', 'username': username}),
          mimeType: MimeType.json,
        ),
      );
    } else {
      return Response.unauthorized();
    }
  });
  // end:doctag<auth-complete>

  // Read and process request body content.
  // doctag<body-handling-complete>
  app.post('/submit', (final req) async {
    final bodyText = await req.readAsString();
    return Response.ok(
      body: Body.fromString(
        jsonEncode({'received': bodyText, 'length': bodyText.length}),
        mimeType: MimeType.json,
      ),
    );
  });
  // end:doctag<body-handling-complete>

  // Parse and validate JSON request bodies.
  // doctag<json-api-complete>
  app.post('/api/users', (final req) async {
    try {
      final bodyText = await req.readAsString();
      final data = jsonDecode(bodyText) as Map<String, dynamic>;

      final name = data['name'] as String?;
      final email = data['email'] as String?;

      if (name == null || email == null) {
        return Response.badRequest(
          body: Body.fromString(
            jsonEncode({'error': 'Name and email are required'}),
            mimeType: MimeType.json,
          ),
        );
      }

      // Create a mock user object with generated data.
      final newUser = {
        'id': DateTime.now().millisecondsSinceEpoch,
        'name': name,
        'email': email,
        'created_at': DateTime.now().toIso8601String(),
      };

      return Response.ok(
        body: Body.fromString(
          jsonEncode({'message': 'User created', 'user': newUser}),
          mimeType: MimeType.json,
        ),
      );
    } catch (e) {
      return Response.badRequest(
        body: Body.fromString(
          jsonEncode({'error': 'Invalid JSON: $e'}),
          mimeType: MimeType.json,
        ),
      );
    }
  });
  // end:doctag<json-api-complete>

  // Process request body as a streaming byte sequence.
  // doctag<upload-complete>
  app.post('/upload', (final req) async {
    if (req.isEmpty) {
      return Response.badRequest(
        body: Body.fromString(
          jsonEncode({'error': 'Request body is required'}),
          mimeType: MimeType.json,
        ),
      );
    }

    final stream = req.read(); // Stream<Uint8List>
    int totalBytes = 0;

    await for (final chunk in stream) {
      totalBytes += chunk.length;
      // Process chunk...
    }

    return Response.ok(
      body: Body.fromString(
        jsonEncode({
          'message': 'Upload successful',
          'bytes_received': totalBytes,
        }),
        mimeType: MimeType.json,
      ),
    );
  });
  // end:doctag<upload-complete>

  // Generate and return HTML content.
  // doctag<html-response>
  app.get('/page', (final req) {
    final pageNum = req.url.queryParameters['page'];

    if (pageNum != null) {
      final page = int.tryParse(pageNum);
      if (page == null || page < 1) {
        return Response.badRequest(
          body: Body.fromString('Invalid page number'),
        );
      }
    }

    final html = '''
<!DOCTYPE html>
<html>
<head><title>My Page</title></head>
<body>
  <h1>Welcome!</h1>
  <p>Page: ${pageNum ?? "1"}</p>
</body>
</html>
''';

    return Response.ok(body: Body.fromString(html, mimeType: MimeType.html));
  });
  // end:doctag<html-response>

  // Return responses with custom HTTP status codes.
  // doctag<custom-status>
  app.get('/teapot', (final req) {
    return Response(
      418, // I'm a teapot
      body: Body.fromString('I refuse to brew coffee'),
    );
  });
  // end:doctag<custom-status>

  // Serve binary data with appropriate content types.
  // doctag<binary-response>
  app.get('/image.png', (final req) {
    final imageBytes = Uint8List.fromList([1, 2, 3, 4]); // Mock image data.
    return Response.ok(body: Body.fromData(imageBytes));
  });
  // end:doctag<binary-response>

  // Stream data using chunked transfer encoding.
  // doctag<streaming-response>
  app.get('/large-file', (final req) {
    final dataStream = Stream.fromIterable([
      Uint8List.fromList([1, 2, 3]),
      Uint8List.fromList([4, 5, 6]),
    ]);

    return Response.ok(
      body: Body.fromDataStream(
        dataStream,
        mimeType: MimeType.octetStream,
        contentLength: 6, // Optional but recommended.
      ),
    );
  });
  // end:doctag<streaming-response>

  // Return empty responses using different methods.
  // doctag<empty-responses>
  app.get('/empty1', (final req) {
    // Return an explicitly empty response body.
    return Response.ok(body: Body.empty());
  });

  app.get('/empty2', (final req) {
    // Use noContent() for a 204 status with no body.
    return Response.noContent();
  });
  // end:doctag<empty-responses>

  // Add custom headers to responses.
  // doctag<response-headers>
  app.get('/api/data', (final req) {
    final headers = Headers.build((final h) {
      // Configure cache control headers.
      h.cacheControl = CacheControlHeader(maxAge: 3600, publicCache: true);

      // Add a custom application header.
      h['X-Custom-Header'] = ['value'];
    });

    return Response.ok(
      headers: headers,
      body: Body.fromString(
        jsonEncode({
          'status': 'ok',
          'timestamp': DateTime.now().toIso8601String(),
        }),
        mimeType: MimeType.json,
      ),
    );
  });
  // end:doctag<response-headers>

  await app.serve();
  log('Server is running on http://localhost:8080');
  log('Try these examples:');
  log('  GET  /info - Basic request/response');
  log('  GET  /users/123 - Path parameters');
  log('  GET  /search?query=test&page=1 - Query parameters');
  log('  GET  /filter?tag=dart&tag=server - Multiple query values');
  log('  GET  /headers-info - Header inspection');
  log('  GET  /protected - Authorization (add Authorization header)');
  log('  POST /submit - Body handling');
  log('  POST /api/users - JSON API');
  log('  POST /upload - File upload');
  log('  GET  /page?page=2 - HTML response');
  log('  GET  /teapot - Custom status code');
  log('  GET  /image.png - Binary response');
  log('  GET  /large-file - Streaming response');
  log('  GET  /empty1 - Empty response');
  log('  GET  /api/data - Response with headers');
}
