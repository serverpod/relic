import 'package:relic/relic.dart';

Response say(String text) => Response.ok(body: Body.fromString('$text\n'));

// doctag<hot-reload-named>
Response hello(Request req) => say('Hello, version 1');
// end:doctag<hot-reload-named>

// doctag<hot-reload-injectable>
class ApiRoutes implements RouterInjectable {
  @override
  void injectIn(RelicRouter router) {
    router.get('/api/status', (req) => say('Status, version 1'));
  }
}
// end:doctag<hot-reload-injectable>

Future<void> main() async {
  // doctag<hot-reload-app>
  final app = RelicApp()
    ..get('/hello', hello)
    ..get('/inline', (req) => say('Inline, version 1'))
    ..inject(ApiRoutes());
  // end:doctag<hot-reload-app>

  await app.serve();
}
