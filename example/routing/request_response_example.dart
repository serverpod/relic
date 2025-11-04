import 'dart:convert';
import 'dart:developer';
import 'dart:typed_data';
import 'package:relic/io_adapter.dart';
import 'package:relic/relic.dart';

// Consolidated examples from requests.md and responses.md
// This file demonstrates complete request-response cycles
Future<void> main() async {
  final app = RelicApp();

  // Basic request method and response
  // doctag<basic-request-response>
  app.get('/info', (final ctx) {
    final method = ctx.request.method; // Method.get
    return ctx.respond(
      Response.ok(body: Body.fromString('Received a ${method.name} request')),
    );
  });
  // end:doctag<basic-request-response>

  // Path parameters with response
  // doctag<path-params-complete>
  app.get('/users/:id', (final ctx) {
    final id = ctx.pathParameters[#id]!;
    final url = ctx.request.url;
    final fullUri = ctx.request.requestedUri;

    log('Relative URL: $url, id: $id');
    log('Full URI: $fullUri');

    // Return user data as JSON
    final user = {
      'id': int.tryParse(id),
      'name': 'User $id',
      'email': 'user$id@example.com',
    };

    return ctx.respond(
      Response.ok(
        body: Body.fromString(jsonEncode(user), mimeType: MimeType.json),
      ),
    );
  });
  // end:doctag<path-params-complete>

  // Query parameters with validation and response
  // doctag<query-params-complete>
  app.get('/search', (final ctx) {
    final query = ctx.request.url.queryParameters['query'];
    final page = ctx.request.url.queryParameters['page'];

    if (query == null) {
      return ctx.respond(
        Response.badRequest(
          body: Body.fromString('Query parameter "query" is required'),
        ),
      );
    }

    final pageNum = int.tryParse(page ?? '1') ?? 1;
    final results = {
      'query': query,
      'page': pageNum,
      'results': ['Result 1', 'Result 2', 'Result 3'],
    };

    return ctx.respond(
      Response.ok(
        body: Body.fromString(jsonEncode(results), mimeType: MimeType.json),
      ),
    );
  });
  // end:doctag<query-params-complete>

  // Multiple query parameters
  // doctag<query-multi-complete>
  app.get('/filter', (final ctx) {
    final tags = ctx.request.url.queryParametersAll['tag'] ?? [];
    final results = {
      'tags': tags,
      'filtered_items':
          tags.map((final tag) => 'Item tagged with $tag').toList(),
    };

    return ctx.respond(
      Response.ok(
        body: Body.fromString(jsonEncode(results), mimeType: MimeType.json),
      ),
    );
  });
  // end:doctag<query-multi-complete>

  // Headers inspection with response
  // doctag<headers-complete>
  app.get('/headers-info', (final ctx) {
    final request = ctx.request;

    // Get typed values
    final mimeType = request.mimeType; // MimeType? (from Content-Type)
    final userAgent = request.headers.userAgent; // String?
    final contentLength = request.headers.contentLength; // int?

    final info = {
      'browser': userAgent ?? 'Unknown',
      'content_type': mimeType?.toString() ?? 'None',
      'content_length': contentLength ?? 0,
    };

    return ctx.respond(
      Response.ok(
        body: Body.fromString(jsonEncode(info), mimeType: MimeType.json),
      ),
    );
  });
  // end:doctag<headers-complete>

  // Authorization with proper response
  // doctag<auth-complete>
  app.get('/protected', (final ctx) {
    final auth = ctx.request.headers.authorization;

    if (auth is BearerAuthorizationHeader) {
      final token = auth.token;
      // In real app, validate token here
      return ctx.respond(
        Response.ok(
          body: Body.fromString(
            jsonEncode({
              'message': 'Access granted',
              'token_length': token.length,
            }),
            mimeType: MimeType.json,
          ),
        ),
      );
    } else if (auth is BasicAuthorizationHeader) {
      final username = auth.username;
      // In real app, validate credentials here
      return ctx.respond(
        Response.ok(
          body: Body.fromString(
            jsonEncode({
              'message': 'Basic auth received',
              'username': username,
            }),
            mimeType: MimeType.json,
          ),
        ),
      );
    } else {
      return ctx.respond(Response.unauthorized());
    }
  });
  // end:doctag<auth-complete>

  // Request body handling with response
  // doctag<body-handling-complete>
  app.post('/submit', (final ctx) async {
    final bodyText = await ctx.request.readAsString();
    return ctx.respond(
      Response.ok(
        body: Body.fromString(
          jsonEncode({'received': bodyText, 'length': bodyText.length}),
          mimeType: MimeType.json,
        ),
      ),
    );
  });
  // end:doctag<body-handling-complete>

  // JSON API with full request/response cycle
  // doctag<json-api-complete>
  app.post('/api/users', (final ctx) async {
    try {
      final bodyText = await ctx.request.readAsString();
      final data = jsonDecode(bodyText) as Map<String, dynamic>;

      final name = data['name'] as String?;
      final email = data['email'] as String?;

      if (name == null || email == null) {
        return ctx.respond(
          Response.badRequest(
            body: Body.fromString(
              jsonEncode({'error': 'Name and email are required'}),
              mimeType: MimeType.json,
            ),
          ),
        );
      }

      // Simulate user creation
      final newUser = {
        'id': DateTime.now().millisecondsSinceEpoch,
        'name': name,
        'email': email,
        'created_at': DateTime.now().toIso8601String(),
      };

      return ctx.respond(
        Response.ok(
          body: Body.fromString(
            jsonEncode({'message': 'User created', 'user': newUser}),
            mimeType: MimeType.json,
          ),
        ),
      );
    } catch (e) {
      return ctx.respond(
        Response.badRequest(
          body: Body.fromString(
            jsonEncode({'error': 'Invalid JSON: $e'}),
            mimeType: MimeType.json,
          ),
        ),
      );
    }
  });
  // end:doctag<json-api-complete>

  // File upload with streaming
  // doctag<upload-complete>
  app.post('/upload', (final ctx) async {
    if (ctx.request.isEmpty) {
      return ctx.respond(
        Response.badRequest(
          body: Body.fromString(
            jsonEncode({'error': 'Request body is required'}),
            mimeType: MimeType.json,
          ),
        ),
      );
    }

    final stream = ctx.request.read(); // Stream<Uint8List>
    int totalBytes = 0;

    await for (final chunk in stream) {
      totalBytes += chunk.length;
      // Process chunk...
    }

    return ctx.respond(
      Response.ok(
        body: Body.fromString(
          jsonEncode({
            'message': 'Upload successful',
            'bytes_received': totalBytes,
          }),
          mimeType: MimeType.json,
        ),
      ),
    );
  });
  // end:doctag<upload-complete>

  // HTML page response
  // doctag<html-response>
  app.get('/page', (final ctx) {
    final pageNum = ctx.request.url.queryParameters['page'];

    if (pageNum != null) {
      final page = int.tryParse(pageNum);
      if (page == null || page < 1) {
        return ctx.respond(
          Response.badRequest(body: Body.fromString('Invalid page number')),
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

    return ctx.respond(
      Response.ok(body: Body.fromString(html, mimeType: MimeType.html)),
    );
  });
  // end:doctag<html-response>

  // Custom status codes
  // doctag<custom-status>
  app.get('/teapot', (final ctx) {
    return ctx.respond(
      Response(
        418, // I'm a teapot
        body: Body.fromString('I refuse to brew coffee'),
      ),
    );
  });
  // end:doctag<custom-status>

  // Binary data response
  // doctag<binary-response>
  app.get('/image.png', (final ctx) {
    final imageBytes = Uint8List.fromList([1, 2, 3, 4]); // Mock image data
    return ctx.respond(Response.ok(body: Body.fromData(imageBytes)));
  });
  // end:doctag<binary-response>

  // Streaming response
  // doctag<streaming-response>
  app.get('/large-file', (final ctx) {
    final dataStream = Stream.fromIterable([
      Uint8List.fromList([1, 2, 3]),
      Uint8List.fromList([4, 5, 6]),
    ]);

    return ctx.respond(
      Response.ok(
        body: Body.fromDataStream(
          dataStream,
          mimeType: MimeType.octetStream,
          contentLength: 6, // Optional but recommended
        ),
      ),
    );
  });
  // end:doctag<streaming-response>

  // Empty responses
  // doctag<empty-responses>
  app.get('/empty1', (final ctx) {
    // Explicitly empty
    return ctx.respond(Response.ok(body: Body.empty()));
  });

  app.get('/empty2', (final ctx) {
    // Or use noContent() which implies an empty body
    return ctx.respond(Response.noContent());
  });
  // end:doctag<empty-responses>

  // Response headers
  // doctag<response-headers>
  app.get('/api/data', (final ctx) {
    final headers = Headers.build((final h) {
      // Set cache control
      h.cacheControl = CacheControlHeader(maxAge: 3600, publicCache: true);

      // Set custom header
      h['X-Custom-Header'] = ['value'];
    });

    return ctx.respond(
      Response.ok(
        headers: headers,
        body: Body.fromString(
          jsonEncode({
            'status': 'ok',
            'timestamp': DateTime.now().toIso8601String(),
          }),
          mimeType: MimeType.json,
        ),
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
