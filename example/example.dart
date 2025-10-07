import 'dart:io';

import 'package:relic/io_adapter.dart';
import 'package:relic/relic.dart';

/// A simple 'Hello World' server
Future<void> main() async {
  // Setup router with fallback
  final router = Router<Handler>()
    ..use('/', logRequests())
    ..fallback = respondWith((final _) => Response.notFound(
        body: Body.fromString("Sorry, that doesn't compute")));

  // Start the server with the handler
  await serve(router.asHandler, InternetAddress.anyIPv4, 8080);

  // Check the _example_ directory for other examples.
}

ResponseContext hello(final NewContext ctx) {
  final name = ctx.pathParameters[#name];
  final age = int.parse(ctx.pathParameters[#age]!);

  return ctx.respond(Response.ok(
      body: Body.fromString('Hello $name! To think you are $age years old.')));
}
