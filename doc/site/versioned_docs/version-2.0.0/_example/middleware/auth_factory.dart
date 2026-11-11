import 'package:relic/relic.dart';

// doctag<middleware-auth-factory>
Middleware requireApiKey(String apiKey) {
  return (next) {
    return (req) {
      if (req.headers['X-API-Key']?.first != apiKey) {
        return Response.unauthorized(
          body: Body.fromString('Invalid API key\n'),
        );
      }
      return next(req);
    };
  };
}
// end:doctag<middleware-auth-factory>

Response protectedHandler(Request req) =>
    Response.ok(body: Body.fromString('This is protected!\n'));

Future<void> main() async {
  // doctag<middleware-auth-factory-use>
  final app = RelicApp()
    ..use('/protected', requireApiKey('secret123'))
    ..get('/protected', protectedHandler);
  // end:doctag<middleware-auth-factory-use>

  await app.serve();
}
