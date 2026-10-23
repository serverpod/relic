import 'package:relic/relic.dart';

// doctag<middleware-auth-function>
Handler requireApiKey(Handler next) {
  return (req) {
    if (req.headers['X-API-Key']?.first != 'secret123') {
      return Response.unauthorized(body: Body.fromString('Invalid API key\n'));
    }
    return next(req);
  };
}
// end:doctag<middleware-auth-function>

Response publicHandler(Request req) =>
    Response.ok(body: Body.fromString('This is public!\n'));

Response protectedHandler(Request req) =>
    Response.ok(body: Body.fromString('This is protected!\n'));

Future<void> main() async {
  // doctag<middleware-auth-function-use>
  final app = RelicApp()
    ..get('/public', publicHandler)
    ..use('/protected', requireApiKey)
    ..get('/protected', protectedHandler);
  // end:doctag<middleware-auth-function-use>

  await app.serve();
}
