// ignore_for_file: avoid_print, prefer_final_parameters

import 'dart:convert';
import 'dart:io';
import 'package:relic/io_adapter.dart';
import 'package:relic/relic.dart';

/// A comprehensive example demonstrating key Relic concepts:
/// - Request handling and properties
/// - Response creation with various status codes
/// - Type-safe headers
/// - Body handling (text, JSON, HTML, binary)
/// - Routing with path parameters
/// - Middleware composition
/// - Pipeline usage
/// - Error handling
/// - WebSocket connections
///
/// This example validates all the inline documentation examples we've added
/// to the Relic source code.
Future<void> main() async {
  final router = Router<Handler>();

  // ============================================================================
  // BASIC REQUEST & RESPONSE EXAMPLES
  // ============================================================================

  // Simple text response
  router.get('/', (ctx) {
    return ctx.respond(
      Response.ok(
        body: Body.fromString('Welcome to Relic Comprehensive Example!'),
      ),
    );
  });

  // ============================================================================
  // REQUEST PROPERTIES
  // ============================================================================

  router.get('/request-info', (ctx) {
    final request = ctx.request;

    // Access request properties
    final method = request.method;
    final path = request.url.path;
    final queryParams = request.url.queryParameters;
    final protocol = request.protocolVersion;

    final info = '''
Request Information:
- Method: $method
- Path: $path
- Query Parameters: $queryParams
- Protocol: HTTP/$protocol
- Is Empty: ${request.isEmpty}
''';

    return ctx.respond(
      Response.ok(body: Body.fromString(info)),
    );
  });

  // ============================================================================
  // QUERY PARAMETERS
  // ============================================================================

  router.get('/search', (ctx) {
    // Single query parameter
    final query = ctx.request.url.queryParameters['q'] ?? 'default';

    // Multiple values for same parameter (?tag=dart&tag=server)
    final tags = ctx.request.url.queryParametersAll['tag'] ?? [];

    final response = '''
Search Query: $query
Tags: ${tags.join(', ')}
''';

    return ctx.respond(
      Response.ok(body: Body.fromString(response)),
    );
  });

  // ============================================================================
  // TYPE-SAFE HEADERS
  // ============================================================================

  router.get('/headers-demo', (ctx) {
    final headers = ctx.request.headers;

    // Type-safe header access
    final userAgent = headers.userAgent ?? 'Unknown';
    final contentType = ctx.request.body.bodyType;
    final accept = headers.accept;
    final host = headers.host;

    final info = '''
Headers:
- User-Agent: $userAgent
- Content-Type: $contentType
- Accept: $accept
- Host: $host
''';

    return ctx.respond(
      Response.ok(body: Body.fromString(info)),
    );
  });

  // Setting response headers
  router.get('/headers-response', (ctx) {
    final headers = Headers.build((h) {
      // Type-safe header setting
      h.cacheControl = CacheControlHeader(
        maxAge: 3600,
        publicCache: true,
      );

      // Custom headers
      h['X-Powered-By'] = ['Relic'];
      h['X-API-Version'] = ['1.0'];
    });

    return ctx.respond(
      Response.ok(
        headers: headers,
        body: Body.fromString('Response with custom headers'),
      ),
    );
  });

  // ============================================================================
  // REQUEST BODY HANDLING
  // ============================================================================

  router.post('/echo', (ctx) async {
    final request = ctx.request;

    // Check if body exists
    if (request.isEmpty) {
      return ctx.respond(
        Response.badRequest(
          body: Body.fromString('Request body is required'),
        ),
      );
    }

    // Read body as string
    final bodyText = await request.readAsString();

    return ctx.respond(
      Response.ok(
        body: Body.fromString('Echo: $bodyText'),
      ),
    );
  });

  router.post('/api/json', (ctx) async {
    final request = ctx.request;

    if (request.isEmpty) {
      return ctx.respond(
        Response.badRequest(
          body: Body.fromString('JSON body required'),
        ),
      );
    }

    try {
      // Parse JSON
      final bodyText = await request.readAsString();
      final data = jsonDecode(bodyText) as Map<String, dynamic>;

      // Create JSON response
      final response = {
        'received': data,
        'timestamp': DateTime.now().toIso8601String(),
      };

      return ctx.respond(
        Response.ok(
          body: Body.fromString(
            jsonEncode(response),
            mimeType: MimeType.json,
          ),
        ),
      );
    } catch (e) {
      return ctx.respond(
        Response.badRequest(
          body: Body.fromString('Invalid JSON: $e'),
        ),
      );
    }
  });

  // ============================================================================
  // RESPONSE TYPES & STATUS CODES
  // ============================================================================

  // 2xx Success responses
  router.get('/success/ok', (ctx) {
    return ctx.respond(
      Response.ok(body: Body.fromString('200 OK')),
    );
  });

  router.get('/success/no-content', (ctx) {
    return ctx.respond(Response.noContent());
  });

  // 3xx Redirect responses
  router.get('/redirect/permanent', (ctx) {
    return ctx.respond(
      Response.movedPermanently(Uri.parse('/new-location')),
    );
  });

  router.get('/redirect/temporary', (ctx) {
    return ctx.respond(
      Response.found(Uri.parse('/temporary-location')),
    );
  });

  router.get('/redirect/see-other', (ctx) {
    return ctx.respond(
      Response.seeOther(Uri.parse('/success')),
    );
  });

  // 4xx Client error responses
  router.get('/error/bad-request', (ctx) {
    return ctx.respond(
      Response.badRequest(
        body: Body.fromString('Bad request example'),
      ),
    );
  });

  router.get('/error/unauthorized', (ctx) {
    return ctx.respond(
      Response.unauthorized(
        body: Body.fromString('Authentication required'),
      ),
    );
  });

  router.get('/error/forbidden', (ctx) {
    return ctx.respond(
      Response.forbidden(
        body: Body.fromString('Access denied'),
      ),
    );
  });

  router.get('/error/not-found', (ctx) {
    return ctx.respond(
      Response.notFound(
        body: Body.fromString('Resource not found'),
      ),
    );
  });

  // 5xx Server error responses
  router.get('/error/server-error', (ctx) {
    return ctx.respond(
      Response.internalServerError(
        body: Body.fromString('Internal server error'),
      ),
    );
  });

  router.get('/error/not-implemented', (ctx) {
    return ctx.respond(
      Response.notImplemented(
        body: Body.fromString('Feature not implemented yet'),
      ),
    );
  });

  // ============================================================================
  // BODY TYPES
  // ============================================================================

  router.get('/body/text', (ctx) {
    return ctx.respond(
      Response.ok(
        body: Body.fromString(
          'Plain text response',
          mimeType: MimeType.plainText,
        ),
      ),
    );
  });

  router.get('/body/html', (ctx) {
    const html = '''
<!DOCTYPE html>
<html>
<head><title>Relic Example</title></head>
<body>
  <h1>HTML Response</h1>
  <p>This is an HTML response from Relic!</p>
</body>
</html>
''';

    return ctx.respond(
      Response.ok(
        body: Body.fromString(html, mimeType: MimeType.html),
      ),
    );
  });

  router.get('/body/json', (ctx) {
    final data = {
      'status': 'success',
      'message': 'JSON response',
      'timestamp': DateTime.now().toIso8601String(),
    };

    return ctx.respond(
      Response.ok(
        body: Body.fromString(
          jsonEncode(data),
          mimeType: MimeType.json,
        ),
      ),
    );
  });

  // ============================================================================
  // PATH PARAMETERS
  // ============================================================================

  router.get('/users/:id', (ctx) {
    final id = ctx.pathParameters[#id];

    return ctx.respond(
      Response.ok(
        body: Body.fromString('User ID: $id'),
      ),
    );
  });

  router.get('/posts/:year/:month/:slug', (ctx) {
    final year = ctx.pathParameters[#year];
    final month = ctx.pathParameters[#month];
    final slug = ctx.pathParameters[#slug];

    return ctx.respond(
      Response.ok(
        body: Body.fromString('Post: $year/$month/$slug'),
      ),
    );
  });

  // ============================================================================
  // HTTP METHODS
  // ============================================================================

  router.post('/api/create', (ctx) {
    return ctx.respond(
      Response.ok(body: Body.fromString('POST request handled')),
    );
  });

  router.put('/api/update/:id', (ctx) {
    final id = ctx.pathParameters[#id];
    return ctx.respond(
      Response.ok(body: Body.fromString('PUT request for ID: $id')),
    );
  });

  router.patch('/api/partial/:id', (ctx) {
    final id = ctx.pathParameters[#id];
    return ctx.respond(
      Response.ok(body: Body.fromString('PATCH request for ID: $id')),
    );
  });

  router.delete('/api/delete/:id', (ctx) {
    final id = ctx.pathParameters[#id];
    return ctx.respond(
      Response.ok(body: Body.fromString('DELETE request for ID: $id')),
    );
  });

  // ============================================================================
  // MIDDLEWARE EXAMPLES
  // ============================================================================

  // Logging middleware using createMiddleware
  final loggingMiddleware = createMiddleware(
    onRequest: (request) {
      print('→ ${request.method} ${request.url}');
      return null; // Continue to handler
    },
    onResponse: (response) {
      print('← ${response.statusCode}');
      return response;
    },
  );

  // Error handling middleware
  final errorHandlerMiddleware = createMiddleware(
    onError: (error, stackTrace) {
      print('Error: $error');
      return Response.internalServerError(
        body: Body.fromString('An error occurred'),
      );
    },
  );

  // Custom middleware - adds headers to all responses
  Handler addHeadersMiddleware(Handler inner) {
    return (NewContext ctx) async {
      final result = await inner(ctx);

      // Only modify if it's a response
      if (result is ResponseContext) {
        final newResponse = result.response.copyWith(
          headers: result.response.headers.transform((h) {
            h['X-Server'] = ['Relic'];
            h['X-Response-Time'] = [DateTime.now().toIso8601String()];
          }),
        );
        return result.respond(newResponse);
      }

      return result;
    };
  }

  // ============================================================================
  // WEBSOCKET EXAMPLE
  // ============================================================================

  router.get('/ws', (ctx) {
    // WebSocket echo server
    return ctx.connect((RelicWebSocket ws) {
      print('WebSocket connected');

      ws.events.listen(
        (message) {
          print('Received: $message');
          ws.trySendText('Echo: $message');
        },
        onDone: () => print('WebSocket disconnected'),
        onError: (Object error) => print('WebSocket error: $error'),
      );

      // Send welcome message
      ws.trySendText('Welcome to Relic WebSocket!');
    });
  });

  // ============================================================================
  // PIPELINE COMPOSITION
  // ============================================================================

  final handler = const Pipeline()
      .addMiddleware(loggingMiddleware)
      .addMiddleware(errorHandlerMiddleware)
      .addMiddleware(addHeadersMiddleware)
      .addMiddleware(routeWith(router))
      .addHandler(
        respondWith(
          (_) => Response.notFound(
            body: Body.fromString('404 - Page not found'),
          ),
        ),
      );

  // ============================================================================
  // START SERVER
  // ============================================================================

  const port = 8080;
  await serve(handler, InternetAddress.anyIPv4, port);

  print('''
🚀 Relic Comprehensive Example Server running on http://localhost:$port

📚 Available Endpoints:

Basic:
  GET  /                          - Welcome message
  GET  /request-info              - Request properties demo
  
Query Parameters:
  GET  /search?q=term&tag=a&tag=b - Query parameters demo
  
Headers:
  GET  /headers-demo              - Request headers demo
  GET  /headers-response          - Response headers demo
  
Request Body:
  POST /echo                      - Echo back request body
  POST /api/json                  - JSON request/response demo
  
Response Types:
  GET  /success/ok                - 200 OK
  GET  /success/no-content        - 204 No Content
  GET  /redirect/permanent        - 301 Moved Permanently
  GET  /redirect/temporary        - 302 Found
  GET  /redirect/see-other        - 303 See Other
  GET  /error/bad-request         - 400 Bad Request
  GET  /error/unauthorized        - 401 Unauthorized
  GET  /error/forbidden           - 403 Forbidden
  GET  /error/not-found           - 404 Not Found
  GET  /error/server-error        - 500 Internal Server Error
  GET  /error/not-implemented     - 501 Not Implemented
  
Body Types:
  GET  /body/text                 - Plain text response
  GET  /body/html                 - HTML response
  GET  /body/json                 - JSON response
  
Path Parameters:
  GET  /users/:id                 - Single parameter
  GET  /posts/:year/:month/:slug  - Multiple parameters
  
HTTP Methods:
  POST   /api/create              - Create resource
  PUT    /api/update/:id          - Update resource
  PATCH  /api/partial/:id         - Partial update
  DELETE /api/delete/:id          - Delete resource
  
WebSocket:
  GET  /ws                        - WebSocket echo server

🧪 Try these curl commands:

curl http://localhost:$port/
curl http://localhost:$port/request-info
curl http://localhost:$port/search?q=relic&tag=dart&tag=server
curl http://localhost:$port/headers-demo
curl -X POST http://localhost:$port/echo -d "Hello Relic"
curl -X POST http://localhost:$port/api/json -H "Content-Type: application/json" -d '{"name":"Alice","age":30}'
curl http://localhost:$port/body/json
curl http://localhost:$port/users/123
curl http://localhost:$port/posts/2024/10/my-post
curl -X PUT http://localhost:$port/api/update/456
curl -X DELETE http://localhost:$port/api/delete/789
''');
}
