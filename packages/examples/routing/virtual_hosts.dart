import 'package:relic/relic.dart';

// doctag<routing-host-parameter>
Response showDashboard(Request req) {
  final tenant = req.rawPathParameters[#tenant];
  return .ok(body: .fromString('The dashboard of $tenant\n'));
}
// end:doctag<routing-host-parameter>

Future<void> main() async {
  // doctag<routing-virtual-hosts>
  final app = RelicApp(useHostWhenRouting: true)
    ..get(
      'www.example.com/',
      (req) => Response.ok(body: .fromString('Welcome to example.com\n')),
    )
    ..get(
      'api.example.com/users',
      (req) => Response.ok(body: .fromString('The users, over the API\n')),
    );
  // end:doctag<routing-virtual-hosts>

  // doctag<routing-host-parameter-route>
  app.get(':tenant/dashboard', showDashboard);
  // end:doctag<routing-host-parameter-route>

  await app.serve();
}
