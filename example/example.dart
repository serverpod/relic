import 'dart:io';

import 'package:relic/io_adapter.dart';
import 'package:relic/relic.dart';

/// A simple 'Hello World' server
Future<void> main() async {
  // Setup router with fallback
  final router = RelicRouter()
    ..use('/', logRequests())
    ..fallback = respondWith(
      (final _) => Response.notFound(
        body: Body.fromString(
          "Sorry, that doesn't compute",
        ),
      ),
    );

  // RelicRouter can be used directly as a Handler via the asHandler extension.
  await serve(router.asHandler, InternetAddress.anyIPv4, 8080);

  // Check the _example_ directory for other examples.
}

ResponseContext hello(final NewContext ctx) {
  final name = ctx.pathParameters[#name];
  final age = int.parse(ctx.pathParameters[#age]!);

  return ctx.respond(
    Response.ok(
      body: Body.fromString('Hello $name! To think you are $age years old.'),
    ),
  );
}
