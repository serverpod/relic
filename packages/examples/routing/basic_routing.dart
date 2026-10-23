import 'package:relic/relic.dart';

Response say(String text) => Response.ok(body: Body.fromString('$text\n'));

Future<void> main() async {
  // doctag<routing-methods>
  final app = RelicApp()
    ..get('/', (req) => say('You asked for /'))
    ..post('/', (req) => say('You posted to /'))
    ..put('/user', (req) => say('User replaced'))
    ..delete('/user', (req) => say('User deleted'))
    ..add(Method.patch, '/user', (req) => say('User updated'))
    ..anyOf({Method.get, Method.post}, '/admin', (req) {
      return say('Admin, by ${req.method.value}');
    });
  // end:doctag<routing-methods>

  // doctag<routing-forward>
  app
    ..get('/v1/users', (req) {
      final moved = req.copyWith(url: req.url.replace(path: '/v2/users'));
      return req.forwardTo(moved);
    })
    ..get('/v2/users', (req) => say('The users, from ${req.url.path}'));
  // end:doctag<routing-forward>

  await app.serve();
}
