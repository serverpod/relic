import 'dart:developer';
import 'package:relic/io_adapter.dart';
import 'package:relic/relic.dart';

// Examples from requests.md and responses.md
Future<void> main() async {
  final app = RelicApp();

  // Success response example
  app.get('/status', (final ctx) {
    return ctx.respond(Response.ok(
      body: Body.fromString('Status is Ok'),
    ));
  });

  // Bad request example
  app.post('/data', (final ctx) async {
    try {
      throw 'Invalid JSON';
    } catch (e) {
      return ctx.respond(Response.badRequest(
        body: Body.fromString('Invalid JSON'),
      ));
    }
  });

  app.get('/header', (final ctx) {
    return ctx.respond(
      Response.ok(
        body: Body.empty(),
        headers: Headers.build(
          (final mh) {
            mh
              ..accept = AcceptHeader(
                mediaRanges: [MediaRange('application', 'json')],
              )
              ..cookie = CookieHeader(
                cookies: [Cookie(name: 'name', value: 'value')],
              );

            mh['X-Custom-Header'] = ['value'];
          },
        ),
      ),
    );
  });

  await app.serve();
  log('Server is running on http://localhost:8080');
  log('Try these examples:');
  log('  curl http://localhost:8080/status');
  log('  curl http://localhost:8080/data');
  log('  curl -v http://localhost:8080/header');
}
