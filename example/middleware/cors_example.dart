import 'dart:convert';
import 'dart:developer';

import 'package:relic/io_adapter.dart';
import 'package:relic/relic.dart';

/// Middleware that handles Cross-Origin Resource Sharing (CORS).
// doctag<middleware-cors-basic>
Middleware corsMiddleware() {
  return (final Handler next) {
    return (final Request req) async {
      // Respond to CORS preflight OPTIONS requests.
      if (req.method == Method.options) {
        return Response.ok(
          headers: Headers.build((final mh) {
            mh['Access-Control-Allow-Origin'] = ['*'];
            mh['Access-Control-Allow-Methods'] = ['GET, POST, OPTIONS'];
            mh['Access-Control-Allow-Headers'] = ['Content-Type'];
          }),
        );
      }

      // Continue processing for non-preflight requests.
      final result = await next(req);

      // Inject CORS headers into the response.
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
// end:doctag<middleware-cors-basic>

/// Simple API handler that returns JSON data.
Future<Response> apiHandler(final Request req) async {
  final data = {'message': 'Hello from CORS API!'};

  return Response.ok(body: Body.fromString(jsonEncode(data)));
}

void main() async {
  final app =
      RelicApp()
        // Enable CORS for all application routes.
        ..use('/', corsMiddleware())
        // Define the main API endpoint.
        ..get('/api', apiHandler);

  await app.serve();
  log('Simple CORS example running on http://localhost:8080');
  log(
    'Test with: curl -H "Origin: https://example.com" http://localhost:8080/api',
  );
}
