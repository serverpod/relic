import 'dart:developer';
import 'package:relic/io_adapter.dart';
import 'package:relic/relic.dart';

/// Middleware that adds a 'Server' header to responses.
// doctag<middleware-add-server-header>
Middleware addServerHeader() {
  return (final Handler next) {
    return (final Request req) async {
      final result = await next(req);

      if (result is Response) {
        final newResponse = result.copyWith(
          headers: result.headers.transform((final mh) => mh.server = 'Relic'),
        );
        return newResponse;
      }

      return result;
    };
  };
}
// end:doctag<middleware-add-server-header>

/// Basic handler that returns a greeting message.
Future<Response> simpleHandler(final Request req) async {
  return Response.ok(body: Body.fromString('Hello from the shared handler!'));
}

/// Compares Pipeline and RelicApp approaches for request handling.
void main() async {
  // doctag<pipeline-usage>
  // Create a handler using the legacy Pipeline API.
  final pipelineHandler = const Pipeline()
      .addMiddleware(logRequests())
      .addMiddleware(addServerHeader())
      .addHandler(simpleHandler);
  // end:doctag<pipeline-usage>

  // doctag<router-usage>
  // Create a handler using the modern RelicApp API.
  final router = RelicApp()
    ..use('/', logRequests())
    ..use('/', addServerHeader())
    ..get('/router', simpleHandler);
  // end:doctag<router-usage>

  // Combine both approaches in a single application for comparison.
  final app = RelicApp()
    ..get('/pipeline', pipelineHandler)
    ..get('/router', router.asHandler);

  await app.serve();
  log('Pipeline example running on http://localhost:8080');
  log('Try: /pipeline (Pipeline) vs /router (Router.use)');
}
