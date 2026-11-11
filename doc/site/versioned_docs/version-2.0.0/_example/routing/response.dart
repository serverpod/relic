import 'dart:convert';

import 'package:relic/relic.dart';

// doctag<responses-hello>
Response hello(Request req) => Response.ok(body: Body.fromString('Hello!\n'));
// end:doctag<responses-hello>

// doctag<responses-errors>
Response findUser(Request req) {
  if (req.rawPathParameters[#id] != '1') return Response.notFound();
  return Response.ok(body: Body.fromString('User 1\n'));
}
// end:doctag<responses-errors>

// doctag<responses-status>
Response teapot(Request req) =>
    Response(418, body: Body.fromString('I refuse to brew coffee\n'));
// end:doctag<responses-status>

// doctag<responses-redirect>
Response oldHome(Request req) => Response.movedPermanently(Uri.parse('/hello'));
// end:doctag<responses-redirect>

// doctag<responses-empty>
Response deleteUser(Request req) => Response.noContent();
// end:doctag<responses-empty>

// doctag<responses-kinds>
Response page(Request req) => Response.ok(
  body: Body.fromString('<h1>Hello</h1>\n', mimeType: MimeType.html),
);

Response data(Request req) => Response.ok(
  body: Body.fromString(
    jsonEncode({'name': 'Nova', 'age': 27}),
    mimeType: MimeType.json,
  ),
);
// end:doctag<responses-kinds>

// doctag<responses-headers>
Response cached(Request req) => Response.ok(
  headers: Headers.build((h) {
    h.cacheControl = CacheControlHeader(maxAge: 3600, publicCache: true);
    h['X-Served-By'] = ['relic'];
  }),
  body: Body.fromString('Keep me for an hour\n'),
);
// end:doctag<responses-headers>

// doctag<responses-dropped-header>
Response mislabeled(Request req) => Response.ok(
  headers: Headers.build((h) => h['Content-Type'] = ['application/json']),
  body: Body.fromString('Plain text after all\n'),
);
// end:doctag<responses-dropped-header>

Future<void> main() async {
  final app = RelicApp()
    ..get('/hello', hello)
    ..get('/users/:id', findUser)
    ..delete('/users/:id', deleteUser)
    ..get('/teapot', teapot)
    ..get('/old-home', oldHome)
    ..get('/page', page)
    ..get('/data', data)
    ..get('/cached', cached)
    ..get('/mislabeled', mislabeled);

  await app.serve();
}
