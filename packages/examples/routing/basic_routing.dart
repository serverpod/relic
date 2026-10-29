import 'package:relic/relic.dart';

Future<void> main() async {
  // doctag<routing-methods>
  final app = RelicApp()
    ..get('/', (req) => Response.ok(body: .fromString('You asked for /\n')))
    ..post('/', (req) => Response.ok(body: .fromString('You posted to /\n')))
    ..put('/user', (req) => Response.ok(body: .fromString('User replaced\n')))
    ..delete('/user', (req) => Response.ok(body: .fromString('User deleted\n')))
    ..add(
      Method.patch,
      '/user',
      (req) => Response.ok(body: .fromString('User updated\n')),
    )
    ..anyOf({Method.get, Method.post}, '/admin', (req) {
      return Response.ok(body: .fromString('Admin, by ${req.method.value}\n'));
    });
  // end:doctag<routing-methods>

  // doctag<routing-forward>
  app
    ..get('/v1/users', (req) {
      final moved = req.copyWith(url: req.url.replace(path: '/v2/users'));
      return req.forwardTo(moved);
    })
    ..get(
      '/v2/users',
      (req) =>
          Response.ok(body: .fromString('The users, from ${req.url.path}\n')),
    );
  // end:doctag<routing-forward>

  await app.serve();
}
