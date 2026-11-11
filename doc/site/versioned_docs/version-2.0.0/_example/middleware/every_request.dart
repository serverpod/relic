import 'package:relic/relic.dart';

Response hello(Request req) => Response.ok(body: Body.fromString('Hello!\n'));

Future<void> main() async {
  // doctag<middleware-every-request>
  final app = RelicApp()..get('/hello', hello);

  final root = RelicApp()
    ..use('/', logRequests())
    ..any('/**', app.asHandler);
  // end:doctag<middleware-every-request>

  await root.serve();
}
