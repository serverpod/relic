import 'dart:convert';

import 'package:relic/relic.dart';

// doctag<requests-inspect>
Response inspect(Request req) {
  final lines = [
    'method:     ${req.method.value}',
    'url:        ${req.url}',
    'path:       ${req.url.path}',
    'query:      ${req.url.query}',
    'protocol:   ${req.protocol.name}',
    'user-agent: ${req.headers.userAgent}',
    'from:       ${req.connectionInfo.remote.display}',
    'body:       ${req.body.contentLength} bytes',
  ];
  return .ok(body: .fromString('${lines.join('\n')}\n'));
}
// end:doctag<requests-inspect>

// doctag<requests-search>
const pageParam = IntQueryParam('page');

Response search(Request req) {
  final query = req.queryParameters.raw['q'];
  if (query == null) {
    return Response.badRequest(body: .fromString('Add ?q= to search\n'));
  }
  final page = req.queryParameters(pageParam) ?? 1;
  final tags = req.url.queryParametersAll['tag'] ?? const [];
  return .ok(
    body: .fromString('Searching for "$query", page $page, tags $tags\n'),
  );
}
// end:doctag<requests-search>

// doctag<requests-credentials>
Response credentials(Request req) {
  final text = switch (req.headers.authorization) {
    BearerAuthorizationHeader(:final token) => 'A bearer token: $token',
    BasicAuthorizationHeader(:final username) => 'User $username, by password',
    null => 'No credentials',
    _ => 'Credentials in another scheme',
  };
  return .ok(body: .fromString('$text\n'));
}
// end:doctag<requests-credentials>

// doctag<requests-text-body>
Future<Response> shout(Request req) async {
  final text = await req.readAsString();
  return .ok(body: .fromString('${text.toUpperCase()}\n'));
}
// end:doctag<requests-text-body>

// doctag<requests-json-body>
Future<Response> createUser(Request req) async {
  final Object? data;
  try {
    data = jsonDecode(await req.readAsString());
  } on FormatException {
    return Response.badRequest(body: .fromString('Not JSON\n'));
  }
  if (data is! Map || data['name'] is! String) {
    return Response.badRequest(body: .fromString('Expected a name\n'));
  }
  return .ok(body: .fromString('Created ${data['name']}\n'));
}
// end:doctag<requests-json-body>

// doctag<requests-copy>
Handler tagRequest(Handler next) {
  return (req) {
    final tagged = req.copyWith(
      headers: req.headers.transform((h) => h['X-Seen-By'] = ['tagRequest']),
    );
    return next(tagged);
  };
}

Response seenBy(Request req) =>
    .ok(body: .fromString('Seen by ${req.headers['X-Seen-By']}\n'));
// end:doctag<requests-copy>

Future<void> main() async {
  // doctag<requests-routes>
  final app = RelicApp()
    ..any('/inspect', inspect)
    ..get('/search', search)
    ..get('/credentials', credentials)
    ..post('/shout', shout)
    ..post('/users', createUser)
    ..use('/seen', tagRequest)
    ..get('/seen', seenBy);
  // end:doctag<requests-routes>

  await app.serve();
}
