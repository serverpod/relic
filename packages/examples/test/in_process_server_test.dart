// doctag<testing-in-process-test>
import 'package:relic/relic.dart';
import 'package:test/test.dart';

import 'in_process_server.dart';

/// Answers 401 to a request without the right x-api-key.
Middleware requireApiKey(String key) =>
    (next) => (req) {
      if (req.headers['x-api-key']?.single != key) {
        return Response.unauthorized();
      }
      return next(req);
    };

Response _ok(Request req) => Response.ok();

final _url = Uri.parse('http://localhost/registry');

void main() {
  test('Given the middleware, when a request has no API key, '
      'then it answers 401', () async {
    final response = await handle(
      requireApiKey('secret')(_ok),
      Method.get,
      _url,
    );

    expect(response.statusCode, 401);
  });

  test('Given the middleware, when a request has the API key, '
      'then the inner handler answers.', () async {
    final response = await handle(
      requireApiKey('secret')(_ok),
      Method.get,
      _url,
      headers: Headers.build((mh) => mh['x-api-key'] = ['secret']),
    );

    expect(response.statusCode, 200);
  });

  test('Given a request built by the server, when the middleware is '
      'called with it directly, then it answers 401', () async {
    final request = await requestFor(Method.post, _url);

    final result = await requireApiKey('secret')(_ok)(request);

    expect((result as Response).statusCode, 401);
  });
}

// end:doctag<testing-in-process-test>
