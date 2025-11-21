import 'dart:convert';
import 'dart:developer';
import 'package:relic/io_adapter.dart';
import 'package:relic/relic.dart';

// Examples from requests.md and responses.md
Future<void> main() async {
  final app = RelicApp();

  // HTTP Method access
  // doctag<requests-method-and-url>
  app.get('/info', (final req) {
    final method = req.method; // Method.get

    return Response.ok(
      body: Body.fromString('Received a ${method.name} request'),
    );
  });
  // end:doctag<requests-method-and-url>

  // Path parameters example
  // doctag<requests-path-params-id>
  app.get('/users/:id', (final req) {
    final id = req.pathParameters[#id]!;
    final matchedPath = req.matchedPath;
    final fullUri = req.url;

    log('Matched path: $matchedPath, id: $id');
    log('Full URI: $fullUri');

    return Response.ok();
  });
  // end:doctag<requests-path-params-id>

  // Query parameters - single values
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

  // Query parameters - multiple values
  // doctag<requests-query-multi>
  app.get('/filter', (final req) {
    final tags = req.url.queryParametersAll['tag'] ?? [];

    return Response.ok(
      body: Body.fromString('Filtering by tags: ${tags.join(", ")}'),
    );
  });
  // end:doctag<requests-query-multi>

  // Type-safe headers
  // doctag<requests-headers-type-safe>
  app.get('/headers-info', (final req) {
    // Get typed values
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

  // Authorization headers
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

  // Reading request body as string
  // doctag<requests-body-as-string>
  app.post('/submit', (final req) async {
    final bodyText = await req.readAsString();
    return Response.ok(body: Body.fromString('Received: $bodyText'));
  });
  // end:doctag<requests-body-as-string>

  // JSON parsing example
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

  // Reading as a byte stream
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

  // Check if body is empty
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

  // Validate query parameters
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

  // Handle missing headers gracefully
  // doctag<requests-headers-user-agent>
  app.get('/info', (final req) {
    final userAgent = req.headers.userAgent;

    final message =
        userAgent != null
            ? 'Your browser: $userAgent'
            : 'Browser information not available';

    return Response.ok(body: Body.fromString(message));
  });
  // end:doctag<requests-headers-user-agent>

  await app.serve();
}
