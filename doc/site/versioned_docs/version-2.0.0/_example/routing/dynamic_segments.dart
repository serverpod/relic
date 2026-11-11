import 'dart:io';

import 'package:relic/relic.dart';

// doctag<routing-typed-param>
const orderIdParam = IntPathParam(#id);

Response showOrder(Request req) {
  final id = req.pathParameters.get(orderIdParam);
  return .ok(body: .fromString('Order $id, and the next one is ${id + 1}\n'));
}
// end:doctag<routing-typed-param>

// doctag<routing-optional-param>
const pageParam = IntPathParam(#page);

Response listPosts(Request req) {
  final page = req.pathParameters(pageParam) ?? 1;
  return .ok(body: .fromString('Posts, page $page\n'));
}
// end:doctag<routing-optional-param>

// doctag<routing-custom-param-inline>
const eventDateParam = PathParam<DateTime>(#date, DateTime.parse);
// end:doctag<routing-custom-param-inline>

// doctag<routing-custom-param-class>
final class DateTimePathParam extends PathParam<DateTime> {
  const DateTimePathParam(Symbol key) : super(key, DateTime.parse);
}

const dateParam = DateTimePathParam(#date);
// end:doctag<routing-custom-param-class>

Response showEvents(Request req) {
  final date = req.pathParameters.get(dateParam);
  return .ok(
    body: .fromString('Events in month ${date.month} of ${date.year}\n'),
  );
}

Future<void> main(List<String> args) async {
  final app = RelicApp()
    // doctag<routing-raw-param>
    ..get('/users/:id', (req) {
      final id = req.pathParameters.raw[#id];
      return Response.ok(body: .fromString('User $id\n'));
    })
    // end:doctag<routing-raw-param>
    // doctag<routing-typed-param-route>
    ..get('/orders/:id', showOrder)
    // end:doctag<routing-typed-param-route>
    // doctag<routing-optional-param-routes>
    ..get('/posts', listPosts)
    ..get('/posts/:page', listPosts)
    // end:doctag<routing-optional-param-routes>
    ..get('/events/:date', showEvents)
    // doctag<routing-wildcard>
    ..get(
      '/files/*/download',
      (req) => Response.ok(body: .fromString('Downloading a file\n')),
    )
    // end:doctag<routing-wildcard>
    // doctag<routing-tail>
    ..get(
      '/static/**',
      (req) => Response.ok(body: .fromString('Serving ${req.remainingPath}\n')),
    )
    ..get(
      '/static/special/report',
      (req) => Response.ok(body: .fromString('The special report\n')),
    )
    // end:doctag<routing-tail>
    // doctag<routing-backtracking>
    ..get('/:entity/:id', (req) {
      final entity = req.rawPathParameters[#entity];
      final id = req.rawPathParameters[#id];
      return Response.ok(body: .fromString('A $entity with id $id\n'));
    })
    ..get(
      '/shop/:id/profile',
      (req) => Response.ok(body: .fromString('A shop profile\n')),
    );
  // end:doctag<routing-backtracking>

  // doctag<routing-no-backtrack>
  final backtrack = !args.contains('--no-backtrack');
  await app.run(
    () => IOAdapter.bind(InternetAddress.loopbackIPv4, port: 8080),
    backtrack: backtrack,
  );
  // end:doctag<routing-no-backtrack>
}
