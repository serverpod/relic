import 'dart:io';

import 'package:relic/relic.dart';

Response say(String text) => Response.ok(body: Body.fromString('$text\n'));

// doctag<routing-typed-param>
const orderIdParam = IntPathParam(#id);

Response showOrder(Request req) {
  final id = req.pathParameters.get(orderIdParam);
  return say('Order $id, and the next one is ${id + 1}');
}
// end:doctag<routing-typed-param>

// doctag<routing-optional-param>
const pageParam = IntPathParam(#page);

Response listPosts(Request req) {
  final page = req.pathParameters(pageParam) ?? 1;
  return say('Posts, page $page');
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
  return say('Events in month ${date.month} of ${date.year}');
}

Future<void> main(List<String> args) async {
  final app = RelicApp()
    // doctag<routing-raw-param>
    ..get('/users/:id', (req) {
      final id = req.pathParameters.raw[#id];
      return say('User $id');
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
    ..get('/files/*/download', (req) => say('Downloading a file'))
    // end:doctag<routing-wildcard>
    // doctag<routing-tail>
    ..get('/static/**', (req) => say('Serving ${req.remainingPath}'))
    ..get('/static/special/report', (req) => say('The special report'))
    // end:doctag<routing-tail>
    // doctag<routing-backtracking>
    ..get('/:entity/:id', (req) {
      final entity = req.rawPathParameters[#entity];
      final id = req.rawPathParameters[#id];
      return say('A $entity with id $id');
    })
    ..get('/shop/:id/profile', (req) => say('A shop profile'));
  // end:doctag<routing-backtracking>

  // doctag<routing-no-backtrack>
  final backtrack = !args.contains('--no-backtrack');
  await app.run(
    () => IOAdapter.bind(InternetAddress.loopbackIPv4, port: 8080),
    backtrack: backtrack,
  );
  // end:doctag<routing-no-backtrack>
}
