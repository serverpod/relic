import 'dart:developer';
import 'package:relic/io_adapter.dart';
import 'package:relic/relic.dart';

/// Simple middleware that adds a header
// doctag<middleware-add-server-header>
Middleware addServerHeader() {
  return (final Handler next) {
    return (final Request req) async {
      final result = await next(req);

      if (result is Response) {
        final newResponse = result.copyWith(
          headers: result.headers.transform(
            (final mh) => mh['Server'] = ['Relic'],
          ),
        );
        return newResponse;
      }

      return result;
    };
  };
}
// end:doctag<middleware-add-server-header>

/// Simple handler
Future<Response> simpleHandler(final Request req) async {
  return Response.ok(body: Body.fromString('Hello from Pipeline!'));
}

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
  final router =
      RelicApp()
        ..use('/', logRequests())
        ..use('/', addServerHeader())
        ..get('/router', (final Request req) async {
          return Response.ok(body: Body.fromString('Hello from Router!'));
        });
  // end:doctag<router-usage>

  // Combine both approaches in a single application for comparison.
  final app =
      RelicApp()
        ..get('/pipeline', pipelineHandler)
        ..get('/router', router.asHandler);

  await app.serve();
  log('Pipeline example running on http://localhost:8080');
  log('Try: /pipeline (Pipeline) vs /router (Router.use)');
}
