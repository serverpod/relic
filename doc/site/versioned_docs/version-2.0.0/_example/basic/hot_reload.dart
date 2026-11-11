import 'package:relic/relic.dart';

// doctag<hot-reload-named>
Response hello(Request req) => .ok(body: .fromString('Hello, version 1\n'));
// end:doctag<hot-reload-named>

// doctag<hot-reload-injectable>
class ApiRoutes implements RouterInjectable {
  @override
  void injectIn(RelicRouter router) {
    router.get(
      '/api/status',
      (req) => Response.ok(body: .fromString('Status, version 1\n')),
    );
  }
}
// end:doctag<hot-reload-injectable>

Future<void> main() async {
  // doctag<hot-reload-app>
  final app = RelicApp()
    ..get('/hello', hello)
    ..get(
      '/inline',
      (req) => Response.ok(body: .fromString('Inline, version 1\n')),
    )
    ..inject(ApiRoutes());
  // end:doctag<hot-reload-app>

  await app.serve();
}
