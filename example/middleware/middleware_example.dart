import 'dart:convert';
import 'dart:developer';

import 'package:relic/io_adapter.dart';
import 'package:relic/relic.dart';

/// Middleware that adds a custom header
// doctag<07-middleware-31>
Middleware addHeaderMiddleware() {
  return (final Handler innerHandler) {
    return (final RequestContext ctx) async {
      final result = await innerHandler(ctx);

      if (result is ResponseContext) {
        final newResponse = result.response.copyWith(
          headers: result.response.headers.transform(
            (final mh) => mh['X-Custom-Header'] = ['Hello from middleware!'],
          ),
        );
        return result.respond(newResponse);
      }

      return result;
    };
  };
}
// end:doctag<07-middleware-31>

/// Timing middleware
Middleware timingMiddleware() {
  return (final Handler innerHandler) {
    return (final RequestContext ctx) async {
      final stopwatch = Stopwatch()..start();

      final result = await innerHandler(ctx);

      stopwatch.stop();
      log('Request took ${stopwatch.elapsedMilliseconds}ms');

      return result;
    };
  };
}

/// Simple error handling middleware
Middleware errorHandlingMiddleware() {
  return (final Handler innerHandler) {
    return (final RequestContext ctx) async {
      try {
        return await innerHandler(ctx);
      } catch (error) {
        return ctx.respond(
          Response.internalServerError(
            body: Body.fromString('Something went wrong'),
          ),
        );
      }
    };
  };
}

/// Simple handlers
Future<ResponseContext> homeHandler(final RequestContext ctx) async {
  return ctx.respond(
    Response.ok(body: Body.fromString('Hello from home page!')),
  );
}

Future<ResponseContext> apiHandler(final RequestContext ctx) async {
  final data = {'message': 'Hello from API!'};

  return ctx.respond(Response.ok(body: Body.fromString(jsonEncode(data))));
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
