import 'dart:io';

import 'package:relic/relic.dart';
import 'package:relic/src/adapter/context.dart';
import 'package:relic/src/middleware/routing_middleware.dart';

/// A simple 'Hello World' server
Future<void> main() async {
  // Setup router
  final router = Router<Handler>()..get('/user/:name/age/:age', hello);

  // Setup a handler.
  //
  // A [Handler] is function consuming and producing [RequestContext]s,
  // but if you are mostly concerned with converting [Request]s to [Response]s
  // (known as a [Responder] in relic parlor) you can use [respondWith] to
  // wrap a [Responder] into a [Handler]
  final handler = const Pipeline()
      .addMiddleware(logRequests())
      .addMiddleware(routeWith(router))
      .addHandler(respondWith((final _) => Response.notFound(
          body: Body.fromString("Sorry, that doesn't compute"))));

  // Start the server with the handler
  await serve(handler, InternetAddress.anyIPv4, 8080);

  // Check the _example_ directory for other examples.
}

ResponseContext hello(final RequestContext ctx) {
  final name = ctx.pathParameters[#name];
  final age = int.parse(ctx.pathParameters[#age]!);

  return (ctx as RespondableContext).withResponse(Response.ok(
      body: Body.fromString('Hello $name! To think you are $age years old.')));
}
