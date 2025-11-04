import 'dart:convert';
import 'dart:developer';
import 'package:relic/io_adapter.dart';
import 'package:relic/relic.dart';

// Examples from requests.md and responses.md
Future<void> main() async {
  final app = RelicApp();

  // HTTP Method access
  app.get('/info', (final ctx) {
    final method = ctx.method; // Method.get

    return Response.ok(
      body: Body.fromString('Received a ${method.name} request'),
    );
  });

  // Path parameters example
  app.get('/users/:id', (final ctx) {
    final id = ctx.pathParameters[#id]!;
    final url = ctx.url;
    final fullUri = ctx.requestedUri;

    log('Relative URL: $url, id: $id');
    log('Full URI: $fullUri');

    return Response.ok();
  });

  // Query parameters - single values
  app.get('/search', (final ctx) {
    final query = ctx.url.queryParameters['query'];
    final page = ctx.url.queryParameters['page'];

    if (query == null) {
      return Response.badRequest(
        body: Body.fromString('Query parameter "query" is required'),
      );
    }

    return Response.ok(
      body: Body.fromString('Searching for: $query (page: ${page ?? "1"})'),
    );
  });

  // Query parameters - multiple values
  app.get('/filter', (final ctx) {
    final tags = ctx.url.queryParametersAll['tag'] ?? [];

    return Response.ok(
      body: Body.fromString('Filtering by tags: ${tags.join(", ")}'),
    );
  });

  // Type-safe headers
  app.get('/headers-info', (final ctx) {
    final request = ctx;

    // Get typed values
    final mimeType = request.mimeType; // MimeType? (from Content-Type)
    final userAgent = request.headers.userAgent; // String?
    final contentLength = request.headers.contentLength; // int?

    return Response.ok(
      body: Body.fromString(
        'Browser: ${userAgent ?? "Unknown"}, '
        'Content-Type: ${mimeType?.toString() ?? "None"}, '
        'Content-Length: ${contentLength ?? "Unknown"}',
      ),
    );
  });

  // Authorization headers
  app.get('/protected', (final ctx) {
    final auth = ctx.headers.authorization;

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

  // Reading request body as string
  app.post('/submit', (final ctx) async {
    final bodyText = await ctx.readAsString();
    return Response.ok(body: Body.fromString('Received: $bodyText'));
  });

  // JSON parsing example
  app.post('/api/users', (final ctx) async {
    try {
      final bodyText = await ctx.readAsString();
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

  // Reading as a byte stream
  app.post('/upload', (final ctx) async {
    final stream = ctx.read(); // Stream<Uint8List>

    int totalBytes = 0;
    await for (final chunk in stream) {
      totalBytes += chunk.length;
      // Process chunk...
    }

    return Response.ok(body: Body.fromString('Uploaded $totalBytes bytes'));
  });

  // Check if body is empty
  app.post('/data', (final ctx) {
    if (ctx.isEmpty) {
      return Response.badRequest(
        body: Body.fromString('Request body is required'),
      );
    }

    // Body exists, safe to read...
    return Response.ok();
  });

  // Validate query parameters
  app.get('/page', (final ctx) {
    final pageStr = ctx.url.queryParameters['page'];

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

  // Handle missing headers gracefully
  app.get('/info', (final ctx) {
    final userAgent = ctx.headers.userAgent;

    final message =
        userAgent != null
            ? 'Your browser: $userAgent'
            : 'Browser information not available';

    return Response.ok(body: Body.fromString(message));
  });

  await app.serve();
}
