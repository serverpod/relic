import 'dart:convert';
import 'dart:developer';
import 'package:relic/io_adapter.dart';
import 'package:relic/relic.dart';

// Comprehensive examples demonstrating request handling patterns.
Future<void> main() async {
  final app = RelicApp();

  // Demonstrate accessing HTTP method information.
  // doctag<requests-method-and-url>
  app.get('/info', (final req) {
    final method = req.method; // Method.get

    return Response.ok(
      body: Body.fromString('Received a ${method.name} request'),
    );
  });
  // end:doctag<requests-method-and-url>

  // Extract and use path parameters from URLs.
  // doctag<requests-path-params-id>
  app.get('/users/:id', (final req) {
    final id = req.rawPathParameters[#id]!;
    final matchedPath = req.matchedPath;
    final fullUri = req.url;

    log('Matched path: $matchedPath, id: $id');
    log('Full URI: $fullUri');

    return Response.ok();
  });
  // end:doctag<requests-path-params-id>

  // Handle single-value query parameters with validation.
  // doctag<requests-query-single>
  app.get('/search', (final req) {
    final query = req.url.queryParameters['query'];
    final page = req.url.queryParameters['page'];

    if (query == null) {
      return Response.badRequest(
        body: Body.fromString('Query parameter "query" is required'),
      );
    }

    return Response.ok(
      body: Body.fromString('Searching for: $query (page: ${page ?? "1"})'),
    );
  });
  // end:doctag<requests-query-single>

  // Process multiple values for the same query parameter.
  // doctag<requests-query-multi>
  app.get('/filter', (final req) {
    final tags = req.url.queryParametersAll['tag'] ?? [];

    return Response.ok(
      body: Body.fromString('Filtering by tags: ${tags.join(", ")}'),
    );
  });
  // end:doctag<requests-query-multi>

  // Access headers using type-safe methods.
  // doctag<requests-headers-type-safe>
  app.get('/headers-info', (final req) {
    // Get typed header values.
    final mimeType = req.mimeType; // MimeType? (from Content-Type)
    final userAgent = req.headers.userAgent; // String?
    final contentLength = req.headers.contentLength; // int?

    return Response.ok(
      body: Body.fromString(
        'Browser: ${userAgent ?? "Unknown"}, '
        'Content-Type: ${mimeType?.toString() ?? "None"}, '
        'Content-Length: ${contentLength ?? "Unknown"}',
      ),
    );
  });
  // end:doctag<requests-headers-type-safe>

  // Handle different types of authorization headers.
  // doctag<requests-authorization-header>
  app.get('/protected', (final req) {
    final auth = req.headers.authorization;

    if (auth is BearerAuthorizationHeader) {
      final token = auth.token;
      // Validate token...
      return Response.ok(body: Body.fromString('Bearer token: $token'));
    } else if (auth is BasicAuthorizationHeader) {
      final username = auth.username;
      final password = auth.password;
      // Validate credentials...
      return Response.ok(
        body: Body.fromString(
          'Basic auth: $username (password length: ${password.length})',
        ),
      );
    } else {
      return Response.unauthorized();
    }
  });
  // end:doctag<requests-authorization-header>

  // Read and process request body content as String values.
  // doctag<requests-body-as-string>
  app.post('/submit', (final req) async {
    final bodyText = await req.readAsString();
    return Response.ok(body: Body.fromString('Received: $bodyText'));
  });
  // end:doctag<requests-body-as-string>

  // Parse and validate JSON request bodies.
  // doctag<requests-json-parse>
  app.post('/api/users', (final req) async {
    try {
      final bodyText = await req.readAsString();
      final data = jsonDecode(bodyText) as Map<String, dynamic>;

      final name = data['name'] as String?;
      final email = data['email'] as String?;

      if (name == null || email == null) {
        return Response.badRequest(
          body: Body.fromString('Name and email are required'),
        );
      }

      // Process user creation...

      return Response.ok(body: Body.fromString('User created: $name'));
    } catch (e) {
      return Response.badRequest(body: Body.fromString('Invalid JSON: $e'));
    }
  });
  // end:doctag<requests-json-parse>

  // Process request body as a streaming byte sequence.
  // doctag<requests-body-byte-stream>
  app.post('/upload', (final req) async {
    final stream = req.read(); // Stream<Uint8List>

    int totalBytes = 0;
    await for (final chunk in stream) {
      totalBytes += chunk.length;
      // Process chunk...
    }

    return Response.ok(body: Body.fromString('Uploaded $totalBytes bytes'));
  });
  // end:doctag<requests-body-byte-stream>

  // Validate that request body is not empty.
  // doctag<requests-body-empty-check>
  app.post('/data', (final req) {
    if (req.isEmpty) {
      return Response.badRequest(
        body: Body.fromString('Request body is required'),
      );
    }

    // Body exists, safe to read...
    return Response.ok();
  });
  // end:doctag<requests-body-empty-check>

  // Implement query parameter validation and parsing.
  // doctag<requests-query-validate-page>
  app.get('/page', (final req) {
    final pageStr = req.url.queryParameters['page'];

    if (pageStr == null) {
      return Response.badRequest(
        body: Body.fromString('Page parameter is required'),
      );
    }

    final page = int.tryParse(pageStr);
    if (page == null || page < 1) {
      return Response.badRequest(body: Body.fromString('Invalid page number'));
    }

    // Use validated page number...
    return Response.ok();
  });
  // end:doctag<requests-query-validate-page>

  // Gracefully handle missing headers.
  // doctag<requests-headers-user-agent>
  app.get('/info', (final req) {
    final userAgent = req.headers.userAgent;

    final message = userAgent != null
        ? 'Your browser: $userAgent'
        : 'Browser information not available';

    return Response.ok(body: Body.fromString(message));
  });
  // end:doctag<requests-headers-user-agent>

  await app.serve();
}
