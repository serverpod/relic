import 'package:relic/relic.dart';

// doctag<middleware-add-server-header>
Handler addServerHeader(Handler next) {
  return (req) async {
    final result = await next(req);
    if (result is! Response) return result;
    return result.copyWith(
      headers: result.headers.transform((h) => h.server = 'Relic'),
    );
  };
}
// end:doctag<middleware-add-server-header>

Response greet(Request req) =>
    Response.ok(body: Body.fromString('Hello from ${req.url.path}\n'));

Future<void> main() async {
  // doctag<pipeline-usage>
  final pipelined = const Pipeline()
      .addMiddleware(logRequests())
      .addMiddleware(addServerHeader)
      .addHandler(greet);
  // end:doctag<pipeline-usage>

  // doctag<router-usage>
  final app = RelicApp()
    ..get('/pipeline', pipelined)
    ..use('/router', logRequests())
    ..use('/router', addServerHeader)
    ..get('/router', greet);
  // end:doctag<router-usage>

  await app.serve();
}
