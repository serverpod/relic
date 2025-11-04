import 'dart:developer';
import 'package:relic/io_adapter.dart';
import 'package:relic/relic.dart';

// Examples from requests.md and responses.md
Future<void> main() async {
  final app = RelicApp();

  // Success response example
  app.get('/status', (final req) {
    return Response.ok(body: Body.fromString('Status is Ok'));
  });

  // Bad request example
  app.post('/api/users', (final req) async {
    try {
      throw 'Invalid JSON';
    } catch (e) {
      return Response.badRequest(body: Body.fromString('Invalid JSON'));
    }
  });

  await app.serve();
  log('Server is running on http://localhost:8080');
  log('Try these examples:');
  log('  curl http://localhost:8080/status');
  log('  curl http://localhost:8080/api/users');
}
