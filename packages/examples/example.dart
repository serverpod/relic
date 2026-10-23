// doctag<hello-world-app>
import 'package:relic/relic.dart';

Future<void> main() async {
  final app = RelicApp()
    ..use('/', logRequests())
    ..get('/', (req) => Response.ok(body: Body.fromString('Hello, world!\n')))
    ..get('/user/:name/age/:age', helloHandler)
    ..fallback = respondWith(
      (_) => Response.notFound(
        body: Body.fromString("Sorry, that doesn't compute.\n"),
      ),
    );

  await app.serve();
}

Response helloHandler(Request req) {
  final name = req.rawPathParameters[#name];
  final age = int.parse(req.rawPathParameters[#age]!);

  return Response.ok(
    body: Body.fromString('Hello, $name! To think you are $age years old.\n'),
  );
}

// end:doctag<hello-world-app>
