import 'package:relic_core/relic_core.dart';

/// Example demonstrating relic_core's platform-agnostic routing and handlers.
void main() {
  // Create a router with handlers
  final router = Router<Handler>()
    ..get('/hello', (_) => Response.ok(body: Body.fromString('Hello!')))
    ..get('/users/:id', (final req) {
      final id = req.rawPathParameters[#id];
      return Response.ok(body: Body.fromString('User: $id'));
    });

  // Look up a route
  final result = router.lookup(Method.get, '/hello');
  print('Found handler: ${result is RouterMatch}');
}
