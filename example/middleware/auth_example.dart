import 'dart:developer';
import 'package:relic/io_adapter.dart';
import 'package:relic/relic.dart';

/// Simple authentication middleware
// doctag<middleware-auth-basic>
Middleware authMiddleware() {
  return (final Handler next) {
    return (final Request req) async {
      // Extract API key from the X-API-Key header.
      final apiKey = req.headers['X-API-Key']?.first;

      if (apiKey != 'secret123') {
        return Response.unauthorized(body: Body.fromString('Invalid API key'));
      }

      log('User authenticated with API key');
      return await next(req);
    };
  };
}
// end:doctag<middleware-auth-basic>

/// Public handler (no auth needed)
Future<Response> publicHandler(final Request req) async {
  return Response.ok(body: Body.fromString('This is public!'));
}

/// Protected handler (needs auth)
Future<Response> protectedHandler(final Request req) async {
  return Response.ok(body: Body.fromString('This is protected!'));
}

void main() async {
  final router =
      RelicApp()
        // Routes accessible without authentication.
        ..get('/public', publicHandler)
        // Routes that require authentication via middleware.
        ..use('/protected', authMiddleware())
        ..get('/protected', protectedHandler);

  await router.serve(port: 8080);
  log('Auth example running on http://localhost:8080');
  log('Try: curl -H "X-API-Key: secret123" http://localhost:8080/protected');
}
