import 'dart:io';

import 'package:relic/io_adapter.dart';
import 'package:relic/relic.dart';

/// A simple 'Hello World' server
Future<void> main() async {
  // Setup router
  final router = Router<Handler>()
    ..get('/user/:name/age/:age', hello)
    ..use('/', logRequests());

  // Setup a handler.
  //
  // Router<Handler> can be used directly as a Handler via the asHandler extension.
  // When a route doesn't match, it returns 404. You can compose with Cascade
  // to provide custom fallback behavior.
  final handler = const Pipeline().addMiddleware(logRequests()).addHandler(
        Cascade()
            .add(router.asHandler) // pass router as a Handler
            .add(respondWith((final _) => Response.notFound(
                body: Body.fromString("Sorry, that doesn't compute"))))
            .handler,
      );

  // Start the server with the handler
  await serve(handler, InternetAddress.anyIPv4, 8080);

  // Check the _example_ directory for other examples.
}

ResponseContext hello(final NewContext ctx) {
  final name = ctx.pathParameters[#name];
  final age = int.parse(ctx.pathParameters[#age]!);

  return ctx.respond(Response.ok(
      body: Body.fromString('Hello $name! To think you are $age years old.')));
}
