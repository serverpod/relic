import 'package:relic/relic.dart';

Future<void> main() async {
  // doctag<hello-step-3-app>
  final app = RelicApp()
    ..use('/', logRequests())
    ..get('/', (req) => Response.ok(body: Body.fromString('Hello, world!\n')))
    ..get('/user/:name/age/:age', helloHandler);
  // end:doctag<hello-step-3-app>

  await app.serve();
}

Response helloHandler(Request req) {
  final name = req.rawPathParameters[#name];
  final age = int.parse(req.rawPathParameters[#age]!);

  return Response.ok(
    body: Body.fromString('Hello, $name! To think you are $age years old.\n'),
  );
}
