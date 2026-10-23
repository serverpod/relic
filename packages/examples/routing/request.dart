import 'dart:convert';

import 'package:relic/relic.dart';

Response say(String text) => Response.ok(body: Body.fromString('$text\n'));

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
  return say(lines.join('\n'));
}
// end:doctag<requests-inspect>

// doctag<requests-search>
const pageParam = IntQueryParam('page');

Response search(Request req) {
  final query = req.queryParameters.raw['q'];
  if (query == null) {
    return Response.badRequest(body: Body.fromString('Add ?q= to search\n'));
  }
  final page = req.queryParameters(pageParam) ?? 1;
  final tags = req.url.queryParametersAll['tag'] ?? const [];
  return say('Searching for "$query", page $page, tags $tags');
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
  return say(text);
}
// end:doctag<requests-credentials>

// doctag<requests-text-body>
Future<Response> shout(Request req) async {
  final text = await req.readAsString();
  return say(text.toUpperCase());
}
// end:doctag<requests-text-body>

// doctag<requests-json-body>
Future<Response> createUser(Request req) async {
  final Object? data;
  try {
    data = jsonDecode(await req.readAsString());
  } on FormatException {
    return Response.badRequest(body: Body.fromString('Not JSON\n'));
  }
  if (data is! Map || data['name'] is! String) {
    return Response.badRequest(body: Body.fromString('Expected a name\n'));
  }
  return say('Created ${data['name']}');
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

Response seenBy(Request req) => say('Seen by ${req.headers['X-Seen-By']}');
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
