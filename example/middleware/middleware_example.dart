import 'dart:convert';
import 'dart:developer';

import 'package:relic/io_adapter.dart';
import 'package:relic/relic.dart';

/// Middleware that adds a custom header
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

/// Timing middleware
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

/// Simple error handling middleware
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

/// Simple handlers
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
        // Apply middleware to all routes
        ..use('/', logRequests())
        ..use('/', timingMiddleware())
        ..use('/', addHeaderMiddleware())
        // Routes
        ..get('/', homeHandler)
        ..use('/api', errorHandlingMiddleware())
        ..get('/api', apiHandler);

  await app.serve();
  log('Middleware example running on http://localhost:8080');
}
