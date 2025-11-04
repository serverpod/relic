import 'dart:convert';
import 'dart:developer';

import 'package:relic/io_adapter.dart';
import 'package:relic/relic.dart';

/// Simple CORS middleware
Middleware corsMiddleware() {
  return (final Handler innerHandler) {
    return (final Request ctx) async {
      // Handle preflight requests
      if (ctx.method == Method.options) {
        return Response.ok(
          headers: Headers.build((final mh) {
            mh['Access-Control-Allow-Origin'] = ['*'];
            mh['Access-Control-Allow-Methods'] = ['GET, POST, OPTIONS'];
            mh['Access-Control-Allow-Headers'] = ['Content-Type'];
          }),
        );
      }

      // Process normal request
      final result = await innerHandler(ctx);

      // Add CORS headers to response
      if (result is Response) {
        final newResponse = result.copyWith(
          headers: result.headers.transform(
            (final mh) => mh['Access-Control-Allow-Origin'] = ['*'],
          ),
        );
        return newResponse;
      }

      return result;
    };
  };
}

/// API handler
Future<Response> apiHandler(final Request ctx) async {
  final data = {'message': 'Hello from CORS API!'};

  return Response.ok(body: Body.fromString(jsonEncode(data)));
}

void main() async {
  final app =
      RelicApp()
        // Apply CORS to all routes
        ..use('/', corsMiddleware())
        // API route
        ..get('/api', apiHandler);

  await app.serve();
  log('Simple CORS example running on http://localhost:8080');
  log(
    'Test with: curl -H "Origin: https://example.com" http://localhost:8080/api',
  );
}
