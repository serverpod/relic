import 'dart:async';
import 'dart:developer';
import 'dart:isolate';

import 'package:http/http.dart' as http;
import 'package:relic/relic.dart';

/// Demonstrates authentication middleware with context properties.
Future<void> main() async {
  // Start the server in a separate isolate for testing.
  final server = await Isolate.spawn((_) async {
    final app = RelicApp()
      // Protect /api routes with authentication middleware.
      ..use('/api', AuthMiddleware().asMiddleware)
      ..get(
        '/api/user/info',
        (final req) => Response.ok(body: Body.fromString('${req.user}')),
      );

    await app.serve();
  }, null);

  // Make a test request to the protected endpoint.
  final response = await http.get(
    Uri.parse('http://localhost:8080/api/user/info'),
    headers: {
      // Example bearer token.
      'Authorization': 'Bearer 42',
    },
  );

  log(response.body);

  // Forcefully terminate the server isolate.
  server.kill();
}

// Simplified user representation for demo.
typedef User = int;
final _auth = ContextProperty<User>('auth');

/// Extension to provide easy access to the authenticated user.
extension on Request {
  User get user => _auth.get(this);
}

/// Simple authentication middleware for demonstration purposes.
class AuthMiddleware {
  // Simplified validation for demo.
  bool _validate(final String token) => true;
  User _extractUser(final String token) => int.parse(token);

  Handler call(final Handler next) {
    return (final req) {
      final bearer = req.headers.authorization as BearerAuthorizationHeader?;
      if (bearer == null || !_validate(bearer.token)) {
        return Response.unauthorized();
      } else {
        _auth[req] = _extractUser(bearer.token);
        return next(req);
      }
    };
  }

  Middleware get asMiddleware => call;
}
