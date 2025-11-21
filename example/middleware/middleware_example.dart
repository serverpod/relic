import 'dart:convert';
import 'dart:developer';

import 'package:relic/io_adapter.dart';
import 'package:relic/relic.dart';

// doctag<simple-middleware>
Middleware myMiddleware() {
  return (final Handler innerHandler) {
    return (final Request ctx) async {
      // Add logic here to run before the request is processed.

      final result = await innerHandler(ctx);

      // Add logic here to run after the request is processed.

      return result;
    };
  };
}
// end:doctag<simple-middleware>

/// Middleware that adds a custom header to all responses.
// doctag<middleware-add-custom-header>
Middleware addHeaderMiddleware() {
  return (final Handler next) {
    return (final Request req) async {
      final result = await next(req);

      if (result is Response) {
        final newResponse = result.copyWith(
          headers: result.headers.transform(
            (final mh) => mh['X-Custom-Header'] = ['Hello from middleware!'],
          ),
        );
        return newResponse;
      }

      return result;
    };
  };
}
// end:doctag<middleware-add-custom-header>

/// Middleware that logs request processing time.
Middleware timingMiddleware() {
  return (final Handler next) {
    return (final Request req) async {
      final stopwatch = Stopwatch()..start();

      final result = await next(req);

      stopwatch.stop();
      log('Request took ${stopwatch.elapsedMilliseconds}ms');

      return result;
    };
  };
}

/// Middleware that catches and handles errors gracefully.
Middleware errorHandlingMiddleware() {
  return (final Handler next) {
    return (final Request req) async {
      try {
        return await next(req);
      } catch (error) {
        return Response.internalServerError(
          body: Body.fromString('Something went wrong'),
        );
      }
    };
  };
}

/// Basic request handlers for demonstration.
Future<Response> homeHandler(final Request req) async {
  return Response.ok(body: Body.fromString('Hello from home page!'));
}

Future<Response> apiHandler(final Request req) async {
  final data = {'message': 'Hello from API!'};

  return Response.ok(body: Body.fromString(jsonEncode(data)));
}

void main() async {
  final app =
      RelicApp()
        // Apply middleware globally to all routes.
        ..use('/', logRequests())
        ..use('/', timingMiddleware())
        ..use('/', addHeaderMiddleware())
        // Define application routes.
        ..get('/', homeHandler)
        ..use('/api', errorHandlingMiddleware())
        ..get('/api', apiHandler);

  await app.serve();
  log('Middleware example running on http://localhost:8080');
}
