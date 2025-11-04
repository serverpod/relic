import 'package:relic/io_adapter.dart';
import 'package:relic/relic.dart';

/// A simple 'Hello World' server
Future<void> main() async {
  // Setup app
  final app =
      RelicApp()
        ..get(
          '/user/:name/age/:age',
          hello,
        ) // route with parameters (:name & :age)
        ..use('/', logRequests()) // middleware on all paths below '/'
        // custom fallback - optional (default is 404 Not Found)
        ..fallback = respondWith(
          (_) => Response.notFound(
            body: Body.fromString("Sorry, that doesn't compute"),
          ),
        );

  // Start the server. Defaults to using port 8080 on loopback interface
  await app.serve();
}

ResponseContext hello(final Request ctx) {
  final name = ctx.pathParameters[#name];
  final age = int.parse(ctx.pathParameters[#age]!);

  return Response.ok(
    body: Body.fromString('Hello $name! To think you are $age years old.'),
  );
}
