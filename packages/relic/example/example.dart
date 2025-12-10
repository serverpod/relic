import 'package:relic/relic.dart';

/// A simple 'Hello World' server demonstrating basic Relic usage.
Future<void> main() async {
  final app = RelicApp()..get('/hello/:name', helloHandler);

  await app.serve();
}

Response helloHandler(final Request req) {
  final name = req.rawPathParameters[#name];
  return Response.ok(body: Body.fromString('Hello, $name!\n'));
}
