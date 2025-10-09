import 'dart:io';

import 'package:relic/io_adapter.dart';
import 'package:relic/relic.dart';

/// A simple 'Hello World' server
Future<void> main() async {
  // Setup app
  final app = RelicApp()
    ..get('/user/:name/age/:age', hello) // route with parameters (:name & :age)
    ..use('/', logRequests()) // middleware on all paths below '/'
    // custom fallback - optional (default is 404 Not Found)
    ..fallback = respondWith((final _) => Response.notFound(
        body: Body.fromString("Sorry, that doesn't compute")));

  // run app on an IOAdaptor (dart:io HttpServer)
  await app.run(() => IOAdapter.bind(InternetAddress.anyIPv4, port: 8080));
}

ResponseContext hello(final NewContext ctx) {
  final name = ctx.pathParameters[#name];
  final age = int.parse(ctx.pathParameters[#age]!);

  return ctx.respond(Response.ok(
      body: Body.fromString('Hello $name! To think you are $age years old.')));
}
