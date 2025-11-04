import 'dart:convert';
import 'dart:developer';
import 'package:relic/io_adapter.dart';
import 'package:relic/relic.dart';

// Examples from requests.md and responses.md
Future<void> main() async {
  final app = RelicApp();

  // HTTP Method access
  // doctag<requests-method-and-url>
  app.get('/info', (final ctx) {
    final method = ctx.request.method; // Method.get

    return ctx.respond(
      Response.ok(body: Body.fromString('Received a ${method.name} request')),
    );
  });
  // end:doctag<requests-method-and-url>

  // Path parameters example
  // doctag<requests-path-params-id>
  app.get('/users/:id', (final ctx) {
    final id = ctx.pathParameters[#id]!;
    final url = ctx.request.url;
    final fullUri = ctx.request.requestedUri;

    log('Relative URL: $url, id: $id');
    log('Full URI: $fullUri');

    return ctx.respond(Response.ok());
  });
  // end:doctag<requests-path-params-id>

  // Query parameters - single values
  // doctag<requests-query-single>
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

    return ctx.respond(
      Response.ok(
        body: Body.fromString('Searching for: $query (page: ${page ?? "1"})'),
      ),
    );
  });
  // end:doctag<requests-query-single>

  // Query parameters - multiple values
  // doctag<requests-query-multi>
  app.get('/filter', (final ctx) {
    final tags = ctx.request.url.queryParametersAll['tag'] ?? [];

    return ctx.respond(
      Response.ok(
        body: Body.fromString('Filtering by tags: ${tags.join(", ")}'),
      ),
    );
  });
  // end:doctag<requests-query-multi>

  // Type-safe headers
  // doctag<requests-headers-type-safe>
  app.get('/headers-info', (final ctx) {
    final request = ctx.request;

    // Get typed values
    final mimeType = request.mimeType; // MimeType? (from Content-Type)
    final userAgent = request.headers.userAgent; // String?
    final contentLength = request.headers.contentLength; // int?

    return ctx.respond(
      Response.ok(
        body: Body.fromString(
          'Browser: ${userAgent ?? "Unknown"}, '
          'Content-Type: ${mimeType?.toString() ?? "None"}, '
          'Content-Length: ${contentLength ?? "Unknown"}',
        ),
      ),
    );
  });
  // end:doctag<requests-headers-type-safe>

  // Authorization headers
  // doctag<requests-authorization-header>
  app.get('/protected', (final ctx) {
    final auth = ctx.request.headers.authorization;

    if (auth is BearerAuthorizationHeader) {
      final token = auth.token;
      // Validate token...
      return ctx.respond(
        Response.ok(body: Body.fromString('Bearer token: $token')),
      );
    } else if (auth is BasicAuthorizationHeader) {
      final username = auth.username;
      final password = auth.password;
      // Validate credentials...
      return ctx.respond(
        Response.ok(
          body: Body.fromString(
            'Basic auth: $username (password length: ${password.length})',
          ),
        ),
      );
    } else {
      return ctx.respond(Response.unauthorized());
    }
  });
  // end:doctag<requests-authorization-header>

  // Reading request body as string
  // doctag<requests-body-as-string>
  app.post('/submit', (final ctx) async {
    final bodyText = await ctx.request.readAsString();
    return ctx.respond(
      Response.ok(body: Body.fromString('Received: $bodyText')),
    );
  });
  // end:doctag<requests-body-as-string>

  // JSON parsing example
  // doctag<requests-json-parse>
  app.post('/api/users', (final ctx) async {
    try {
      final bodyText = await ctx.request.readAsString();
      final data = jsonDecode(bodyText) as Map<String, dynamic>;

      final name = data['name'] as String?;
      final email = data['email'] as String?;

      if (name == null || email == null) {
        return ctx.respond(
          Response.badRequest(
            body: Body.fromString('Name and email are required'),
          ),
        );
      }

      // Process user creation...

      return ctx.respond(
        Response.ok(body: Body.fromString('User created: $name')),
      );
    } catch (e) {
      return ctx.respond(
        Response.badRequest(body: Body.fromString('Invalid JSON: $e')),
      );
    }
  });
  // end:doctag<requests-json-parse>

  // Reading as a byte stream
  // doctag<requests-body-byte-stream>
  app.post('/upload', (final ctx) async {
    final stream = ctx.request.read(); // Stream<Uint8List>

    int totalBytes = 0;
    await for (final chunk in stream) {
      totalBytes += chunk.length;
      // Process chunk...
    }

    return ctx.respond(
      Response.ok(body: Body.fromString('Uploaded $totalBytes bytes')),
    );
  });
  // end:doctag<requests-body-byte-stream>

  // Check if body is empty
  // doctag<requests-body-empty-check>
  app.post('/data', (final ctx) {
    if (ctx.request.isEmpty) {
      return ctx.respond(
        Response.badRequest(body: Body.fromString('Request body is required')),
      );
    }

    // Body exists, safe to read...
    return ctx.respond(Response.ok());
  });
  // end:doctag<requests-body-empty-check>

  // Validate query parameters
  // doctag<requests-query-validate-page>
  app.get('/page', (final ctx) {
    final pageStr = ctx.request.url.queryParameters['page'];

    if (pageStr == null) {
      return ctx.respond(
        Response.badRequest(
          body: Body.fromString('Page parameter is required'),
        ),
      );
    }

    final page = int.tryParse(pageStr);
    if (page == null || page < 1) {
      return ctx.respond(
        Response.badRequest(body: Body.fromString('Invalid page number')),
      );
    }

    // Use validated page number...
    return ctx.respond(Response.ok());
  });
  // end:doctag<requests-query-validate-page>

  // Handle missing headers gracefully
  // doctag<requests-headers-user-agent>
  app.get('/info', (final ctx) {
    final userAgent = ctx.request.headers.userAgent;

    final message =
        userAgent != null
            ? 'Your browser: $userAgent'
            : 'Browser information not available';

    return ctx.respond(Response.ok(body: Body.fromString(message)));
  });
  // end:doctag<requests-headers-user-agent>

  await app.serve();
}
