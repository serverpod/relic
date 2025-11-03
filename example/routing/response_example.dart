import 'dart:developer';
import 'package:relic/io_adapter.dart';
import 'package:relic/relic.dart';

// Examples from requests.md and responses.md
Future<void> main() async {
  final app = RelicApp();

  // Success response example
  // doctag<05-responses-31>
  app.get('/status', (final ctx) {
    return ctx.respond(Response.ok(body: Body.fromString('Status is Ok')));
  });
  // end:doctag<05-responses-31>

  // Bad request example
  // doctag<05-responses-43>
  app.post('/api/users', (final ctx) async {
    try {
      throw 'Invalid JSON';
    } catch (e) {
      return ctx.respond(
        Response.badRequest(body: Body.fromString('Invalid JSON')),
      );
    }
  });
  // end:doctag<05-responses-43>

  await app.serve();
  log('Server is running on http://localhost:8080');
  log('Try these examples:');
  log('  curl http://localhost:8080/status');
  log('  curl http://localhost:8080/api/users');
}
