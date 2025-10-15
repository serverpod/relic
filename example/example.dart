import 'package:relic/io_adapter.dart';
import 'package:relic/relic.dart';

// Creating a dedicated setup class makes
// hot-reload work better.
class _RouterSetup implements RouterInjectable {
  @override
  void injectIn(final RelicRouter router) {
    router
      ..get(
          '/user/:name/age/:age', hello) // route with parameters (:name & :age)
      ..use('/', logRequests()) // middleware on all paths below '/'
      // custom fallback - optional (default is 404 Not Found)
      ..fallback = respondWith((final _) => Response.notFound(
          body: Body.fromString("Sorry, that doesn't compute")));
  }
}

/// A simple 'Hello World' server
Future<void> main() async {
  // Setup app
  final app = RelicApp()..inject(_RouterSetup());

  // Start the server. Defaults to using port 8080 on loopback interface
  await app.serve();
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
