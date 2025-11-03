import 'dart:developer';
import 'package:relic/io_adapter.dart';
import 'package:relic/relic.dart';

/// Simple middleware that adds a header
// doctag<09-middleware-pipeline-6>
Middleware addServerHeader() {
  return (final Handler innerHandler) {
    return (final RequestContext ctx) async {
      final result = await innerHandler(ctx);

      if (result is ResponseContext) {
        final newResponse = result.response.copyWith(
          headers: result.response.headers.transform(
            (final mh) => mh['Server'] = ['Relic'],
          ),
        );
        return result.respond(newResponse);
      }

      return result;
    };
  };
}
// end:doctag<09-middleware-pipeline-6>

/// Simple handler
Future<ResponseContext> simpleHandler(final RequestContext ctx) async {
  return ctx.respond(
    Response.ok(body: Body.fromString('Hello from Pipeline!')),
  );
}

void main() async {
  // Using Pipeline (legacy composition)
  final pipelineHandler = const Pipeline()
      .addMiddleware(logRequests())
      .addMiddleware(addServerHeader())
      .addHandler(simpleHandler);

  // Using Router (preferred)
  final router =
      RelicApp()
        ..use('/', logRequests())
        ..use('/', addServerHeader())
        ..get('/router', (final RequestContext ctx) async {
          return ctx.respond(
            Response.ok(body: Body.fromString('Hello from Router!')),
          );
        });

  // Main router that shows both approaches
  final app =
      RelicApp()
        ..get('/pipeline', pipelineHandler)
        ..get('/router', router.asHandler);

  await app.serve();
  log('Pipeline example running on http://localhost:8080');
  log('Try: /pipeline (Pipeline) vs /router (Router.use)');
}
