import 'dart:developer';
import 'package:relic/io_adapter.dart';
import 'package:relic/relic.dart';

/// Simple authentication middleware
Middleware authMiddleware() {
  return (final Handler innerHandler) {
    return (final NewContext ctx) async {
      // Check for API key in header
      final apiKey = ctx.request.headers['X-API-Key']?.first;

      if (apiKey != 'secret123') {
        return ctx.respond(
          Response.unauthorized(body: Body.fromString('Invalid API key')),
        );
      }

      log('User authenticated with API key');
      return await innerHandler(ctx);
    };
  };
}

/// Public handler (no auth needed)
Future<ResponseContext> publicHandler(final NewContext ctx) async {
  return ctx.respond(Response.ok(body: Body.fromString('This is public!')));
}

/// Protected handler (needs auth)
Future<ResponseContext> protectedHandler(final NewContext ctx) async {
  return ctx.respond(Response.ok(body: Body.fromString('This is protected!')));
}

void main() async {
  final router =
      RelicApp()
        // Public routes
        ..get('/public', publicHandler)
        // Protected routes (with auth middleware)
        ..use('/protected', authMiddleware())
        ..get('/protected', protectedHandler);

  await router.serve(port: 8080);
  log('Auth example running on http://localhost:8080');
  log('Try: curl -H "X-API-Key: secret123" http://localhost:8080/protected');
}
