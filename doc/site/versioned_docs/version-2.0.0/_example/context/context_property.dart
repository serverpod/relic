import 'package:relic/relic.dart';

// doctag<context-prop-define>
class User {
  final String name;
  User(this.name);
}

final userProperty = ContextProperty<User>('user');
// end:doctag<context-prop-define>

const _users = {'key-alice': 'Alice', 'key-bob': 'Bob'};

// doctag<context-prop-set>
Handler authenticate(Handler next) {
  return (req) {
    final name = _users[req.headers['X-API-Key']?.first];
    if (name == null) {
      return Response.unauthorized(body: Body.fromString('Unknown API key\n'));
    }
    userProperty[req] = User(name);
    return next(req);
  };
}
// end:doctag<context-prop-set>

// doctag<context-prop-get>
Response whoAmI(Request req) {
  final user = userProperty.get(req);
  return Response.ok(body: Body.fromString('You are ${user.name}\n'));
}
// end:doctag<context-prop-get>

// doctag<context-prop-extension>
extension on Request {
  User? get user => userProperty[this];
}

Response greet(Request req) {
  final name = req.user?.name ?? 'stranger';
  return Response.ok(body: Body.fromString('Hello, $name\n'));
}
// end:doctag<context-prop-extension>

Future<void> main() async {
  // doctag<context-prop-app>
  final app = RelicApp()
    ..use('/api', authenticate)
    ..get('/api/me', whoAmI)
    ..get('/me', whoAmI)
    ..get('/hello', greet);
  // end:doctag<context-prop-app>

  await app.serve();
}
