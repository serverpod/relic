// doctag<hello-world-app>
import 'package:relic/io_adapter.dart';
import 'package:relic/relic.dart';

/// A simple 'Hello World' server.
Future<void> main() async {
  // Setup the app.
  final app =
      RelicApp()
        // Route with parameters (:name & :age).
        ..get('/user/:name/age/:age', hello)
        // Middleware on all paths below '/'.
        ..use('/', logRequests())
        // Custom fallback - optional (default is 404 Not Found).
        ..fallback = respondWith(
          (_) => Response.notFound(
            body: Body.fromString("Sorry, that doesn't compute.\n"),
          ),
        );

  // Start the server (defaults to using port 8080).
  await app.serve();
}

/// Handles a hello request.
Response hello(final Request req) {
  final name = req.pathParameters[#name];
  final age = int.parse(req.pathParameters[#age]!);

  return Response.ok(
    body: Body.fromString('Hello $name! To think you are $age years old.\n'),
  );
}

// end:doctag<hello-world-app>
