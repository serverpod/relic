import 'package:relic/relic.dart';

Response say(String text) => Response.ok(body: Body.fromString('$text\n'));

// doctag<routing-host-parameter>
Response showDashboard(Request req) {
  final tenant = req.rawPathParameters[#tenant];
  return say('The dashboard of $tenant');
}
// end:doctag<routing-host-parameter>

Future<void> main() async {
  // doctag<routing-virtual-hosts>
  final app = RelicApp(useHostWhenRouting: true)
    ..get('www.example.com/', (req) => say('Welcome to example.com'))
    ..get('api.example.com/users', (req) => say('The users, over the API'));
  // end:doctag<routing-virtual-hosts>

  // doctag<routing-host-parameter-route>
  app.get(':tenant/dashboard', showDashboard);
  // end:doctag<routing-host-parameter-route>

  await app.serve();
}
