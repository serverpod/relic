// ignore_for_file: avoid_print

import 'dart:async';
import 'dart:isolate';

import 'package:http/http.dart' as http;
import 'package:relic/io_adapter.dart';
import 'package:relic/relic.dart';

Future<void> main() async {
  // start server
  final server = await Isolate.spawn((final _) async {
    final app = RelicApp()
      ..use('/api',
          AuthMiddleware().asMiddleware) // <-- add auth middleware on /api
      ..get(
          '/api/user/info',
          (final ctx) =>
              ctx.respond(Response.ok(body: Body.fromString('${ctx.user}'))));

    await app.serve();
  }, null);

  // call with client
  final response = await http.get(
    Uri.parse('http://localhost:8080/api/user/info'),
    headers: {
      'Authorization': 'Bearer 42', // just an example
    },
  );

  print(response.body);

  server.kill(); // stop server again (a bit blunt)
}

typedef User = int; // just an example
final _auth = ContextProperty<User>('auth');

extension on RequestContext {
  User get user => _auth[this];
}

class AuthMiddleware {
  bool _validate(final String token) => true; // just an example
  User _extractUser(final String token) => int.parse(token);

  Handler call(final Handler next) {
    return (final ctx) {
      final bearer =
          ctx.request.headers.authorization as BearerAuthorizationHeader?;
      if (bearer == null || !_validate(bearer.token)) {
        return ctx.respond(Response.unauthorized());
      } else {
        _auth[ctx] = _extractUser(bearer.token);
        return next(ctx);
      }
    };
  }

  Middleware get asMiddleware => call;
}
