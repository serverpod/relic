import 'package:relic/relic.dart';

Future<void> main() async {
  // doctag<hello-step-2-app>
  final app = RelicApp()
    ..get('/', (req) => Response.ok(body: Body.fromString('Hello, world!\n')))
    ..get('/user/:name/age/:age', helloHandler);
  // end:doctag<hello-step-2-app>

  await app.serve();
}

// doctag<hello-step-2-handler>
Response helloHandler(Request req) {
  final name = req.rawPathParameters[#name];
  final age = int.parse(req.rawPathParameters[#age]!);

  return Response.ok(
    body: Body.fromString('Hello, $name! To think you are $age years old.\n'),
  );
}

// end:doctag<hello-step-2-handler>
