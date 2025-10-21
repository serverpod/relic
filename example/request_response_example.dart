// ignore_for_file: avoid_log, prefer_final_parameters

import 'dart:convert';
import 'dart:developer';
import 'package:relic/io_adapter.dart';
import 'package:relic/relic.dart';

// Examples from requests.md and responses.md
Future<void> main() async {
  final app = RelicApp();

  // HTTP Method access
  app.get('/info', (ctx) {
    final method = ctx.request.method; // Method.get

    return ctx.respond(Response.ok(
      body: Body.fromString('Received a ${method.name} request'),
    ));
  });

  // Query parameters - single values
  app.get('/search', (ctx) {
    final query = ctx.request.url.queryParameters['query'];
    final page = ctx.request.url.queryParameters['page'];

    if (query == null) {
      return ctx.respond(Response.badRequest(
        body: Body.fromString('Query parameter "query" is required'),
      ));
    }

    return ctx.respond(Response.ok(
      body: Body.fromString('Searching for: $query (page: ${page ?? "1"})'),
    ));
  });

  // Query parameters - multiple values
  app.get('/filter', (ctx) {
    final tags = ctx.request.url.queryParametersAll['tag'] ?? [];

    return ctx.respond(Response.ok(
      body: Body.fromString('Filtering by tags: ${tags.join(", ")}'),
    ));
  });

  // Type-safe headers
  app.get('/headers-info', (ctx) {
    final request = ctx.request;

    // Get typed values
    final mimeType = request.mimeType; // MimeType? (from Content-Type)
    final userAgent = request.headers.userAgent; // String?
    final contentLength = request.headers.contentLength; // int?

    return ctx.respond(Response.ok(
      body: Body.fromString(
        'Browser: ${userAgent ?? "Unknown"}, '
        'Content-Type: ${mimeType?.toString() ?? "None"}, '
        'Content-Length: ${contentLength ?? "Unknown"}',
      ),
    ));
  });

  // Authorization headers
  app.get('/protected', (ctx) {
    final auth = ctx.request.headers.authorization;

    if (auth is BearerAuthorizationHeader) {
      final token = auth.token;
      // Validate token...
      return ctx.respond(Response.ok(
        body: Body.fromString('Bearer token: $token'),
      ));
    } else if (auth is BasicAuthorizationHeader) {
      final username = auth.username;
      final password = auth.password;
      // Validate credentials...
      return ctx.respond(Response.ok(
        body: Body.fromString(
            'Basic auth: $username (password length: ${password.length})'),
      ));
    } else {
      return ctx.respond(Response.unauthorized());
    }
  });

  // Reading request body as string
  app.post('/submit', (ctx) async {
    final bodyText = await ctx.request.readAsString();
    return ctx.respond(Response.ok(
      body: Body.fromString('Received: $bodyText'),
    ));
  });

  // JSON parsing example
  app.post('/api/users', (ctx) async {
    try {
      final bodyText = await ctx.request.readAsString();
      final data = jsonDecode(bodyText) as Map<String, dynamic>;

      final name = data['name'] as String?;
      final email = data['email'] as String?;

      if (name == null || email == null) {
        return ctx.respond(Response.badRequest(
          body: Body.fromString('Name and email are required'),
        ));
      }

      // Process user creation...

      return ctx.respond(Response.ok(
        body: Body.fromString('User created: $name'),
      ));
    } catch (e) {
      return ctx.respond(Response.badRequest(
        body: Body.fromString('Invalid JSON: $e'),
      ));
    }
  });

  // Check if body is empty
  app.post('/data', (ctx) {
    if (ctx.request.isEmpty) {
      return ctx.respond(Response.badRequest(
        body: Body.fromString('Request body is required'),
      ));
    }

    // Body exists, safe to read...
    return ctx.respond(Response.ok());
  });

  // Path parameters example
  app.get('/users/:id', (ctx) {
    final user = findUser(ctx.pathParameters[#id]);

    return ctx.respond(Response.ok(
      body: Body.fromString('User: ${user.name}'),
    ));
  });

  // 204 No Content example
  app.delete('/users/:id', (ctx) {
    deleteUser(ctx.pathParameters[#id]);

    // Success, but nothing to send back
    return ctx.respond(Response.noContent());
  });

  // Redirect examples
  app.get('/old-url', (ctx) {
    return ctx.respond(Response.movedPermanently(
      Uri.parse('/new-url'),
    ));
  });

  app.get('/temporary', (ctx) {
    return ctx.respond(Response.found(
      Uri.parse('/current-location'),
    ));
  });

  app.post('/submit-form', (ctx) async {
    // Process form submission...

    // Redirect to a success page
    return ctx.respond(Response.seeOther(
      Uri.parse('/success'),
    ));
  });

  // Error responses
  app.get('/dashboard', (ctx) {
    final auth = ctx.request.headers.authorization;

    if (auth == null) {
      return ctx.respond(Response.unauthorized(
        body: Body.fromString('Please log in to continue'),
      ));
    }

    // Validate credentials...
    return ctx.respond(Response.ok());
  });

  app.delete('/admin/users/:id', (ctx) {
    final user = getCurrentUser(ctx);

    if (!user.isAdmin) {
      return ctx.respond(Response.forbidden(
        body: Body.fromString('Admin privileges required'),
      ));
    }

    // Proceed with deletion...
    return ctx.respond(Response.ok());
  });

  // 500 Internal Server Error
  app.get('/data-fetch', (ctx) {
    try {
      final data = fetchData();
      return ctx.respond(Response.ok(
        body: Body.fromString(data),
      ));
    } catch (e) {
      log('Error fetching data: $e');

      return ctx.respond(Response.internalServerError(
        body: Body.fromString('An error occurred. Please try again later.'),
      ));
    }
  });

  // Custom status code
  app.get('/teapot', (ctx) {
    return ctx.respond(Response(
      418, // I'm a teapot
      body: Body.fromString('I refuse to brew coffee'),
    ));
  });

  // HTML response
  app.get('/page/html', (ctx) {
    const html = '''
<!DOCTYPE html>
<html>
<head><title>My Page</title></head>
<body><h1>Welcome!</h1></body>
</html>
''';

    return ctx.respond(Response.ok(
      body: Body.fromString(html, mimeType: MimeType.html),
    ));
  });

  // JSON response
  app.get('/api/users/:id', (ctx) {
    final user = {
      'id': 123,
      'name': 'Alice',
      'email': 'alice@example.com',
    };

    return ctx.respond(Response.ok(
      body: Body.fromString(
        jsonEncode(user),
        mimeType: MimeType.json,
      ),
    ));
  });

  // Response headers
  app.get('/api/data', (ctx) {
    final headers = Headers.build((h) {
      // Set cache control
      h.cacheControl = CacheControlHeader(
        maxAge: 3600,
        publicCache: true,
      );

      // Set custom header
      h['X-Custom-Header'] = ['value'];
    });

    return ctx.respond(Response.ok(
      headers: headers,
      body: Body.fromString('{"status": "ok"}', mimeType: MimeType.json),
    ));
  });

  // BEST PRACTICES

  // Query parameter validation
  app.get('/page', (ctx) {
    final pageStr = ctx.request.url.queryParameters['page'];

    if (pageStr == null) {
      return ctx.respond(Response.badRequest(
        body: Body.fromString('Page parameter is required'),
      ));
    }

    final page = int.tryParse(pageStr);
    if (page == null || page < 1) {
      return ctx.respond(Response.badRequest(
        body: Body.fromString('Invalid page number'),
      ));
    }

    // Use validated page number...
    return ctx.respond(Response.ok(
      body: Body.fromString('Page $page content'),
    ));
  });

  // Handle missing headers gracefully
  app.get('/browser-info', (ctx) {
    final userAgent = ctx.request.headers.userAgent;

    final message = userAgent != null
        ? 'Your browser: $userAgent'
        : 'Browser information not available';

    return ctx.respond(Response.ok(
      body: Body.fromString(message),
    ));
  });

  // Byte stream reading example
  app.post('/upload', (ctx) async {
    final stream = ctx.request.read(); // Stream<Uint8List>

    int totalBytes = 0;
    await for (final chunk in stream) {
      totalBytes += chunk.length;
      // Process chunk...
    }

    return ctx.respond(Response.ok(
      body: Body.fromString('Uploaded $totalBytes bytes'),
    ));
  });

  // FALLBACK

  app.fallback = respondWith(
    (final _) => Response.notFound(
      body: Body.fromString('404 - Page not found'),
    ),
  );

  await app.serve();
  log('🚀 Relic Documentation Examples running on http://localhost:8080');
  log('');
  log('📖 Try these examples from the docs:');
  log('');
  log('Request examples:');
  log('  curl http://localhost:8080/info');
  log('  curl "http://localhost:8080/search?query=relic&page=2"');
  log('  curl "http://localhost:8080/filter?tag=dart&tag=server&tag=web"');
  log('  curl http://localhost:8080/headers-info');
  log('  curl -H "Authorization: Bearer abc123" http://localhost:8080/protected');
  log('  curl -X POST -d "Hello Relic" http://localhost:8080/submit');
  log('  curl -X POST -H "Content-Type: application/json" \\');
  log('       -d \'{"name":"Alice","email":"alice@example.com"}\' \\');
  log('       http://localhost:8080/api/users');
  log('  curl -X POST http://localhost:8080/data');
  log('');
  log('Response examples:');
  log('  curl http://localhost:8080/users/123');
  log('  curl -X DELETE http://localhost:8080/users/123');
  log('  curl http://localhost:8080/old-url');
  log('  curl -X POST http://localhost:8080/submit-form');
  log('  curl http://localhost:8080/dashboard');
  log('  curl -X DELETE http://localhost:8080/admin/users/123');
  log('  curl http://localhost:8080/data-fetch');
  log('  curl http://localhost:8080/teapot');
  log('  curl http://localhost:8080/page');
  log('  curl http://localhost:8080/page/html');
  log('  curl http://localhost:8080/api/users/123');
  log('  curl http://localhost:8080/api/data');
  log('');
  log('Best practices examples:');
  log('  curl "http://localhost:8080/page?page=5"');
  log('  curl http://localhost:8080/browser-info');
  log('  curl -X POST -d "file content" http://localhost:8080/upload');
}

// Mock functions for examples
User findUser(String? id) => User(name: 'User $id', isAdmin: false);
void deleteUser(String? id) => log('Deleted user $id');
User getCurrentUser(NewContext ctx) =>
    User(name: 'Current User', isAdmin: true);
String fetchData() => 'Sample data';

class User {
  final String name;
  final bool isAdmin;
  User({required this.name, required this.isAdmin});
}



/// A custom header for API versioning
final class ApiVersionHeader {
  static const codec = HeaderCodec(ApiVersionHeader.parse, _encode);

  static List<String> _encode(ApiVersionHeader value) => [value.version];

  final String version;

  const ApiVersionHeader(this.version);

  /// Parses the header value into an ApiVersionHeader instance
  factory ApiVersionHeader.parse(Iterable<String> values) {
    final value = values.firstOrNull?.trim();
    if (value == null || value.isEmpty) {
      throw const FormatException('API version cannot be empty');
    }

    // Validate version format (e.g., semantic versioning)
    final versionRegex = RegExp(r'^\d+\.\d+\.\d+$');
    if (!versionRegex.hasMatch(value)) {
      throw const FormatException('Invalid version format. Expected: major.minor.patch');
    }

    return ApiVersionHeader(value);
  }
}