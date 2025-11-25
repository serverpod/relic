import 'package:relic/io_adapter.dart';
import 'package:relic/relic.dart';

/// Examples demonstrating how Relic handles dynamic path segments.
Future<void> main() async {
  final app = RelicApp();

  // Capture a named path parameter and read it from the request.
  // doctag<routing-path-params-id>
  app.get('/users/:id', (final req) {
    final userId = req.rawPathParameters[#id];

    return Response.ok(body: Body.fromString('User $userId'));
  });
  // end:doctag<routing-path-params-id>

  // Match any single path segment when the actual value does not matter.
  // doctag<routing-wildcard-download>
  app.get('/files/*/download', (final req) {
    return Response.ok(body: Body.fromString('Downloading file...'));
  });
  // end:doctag<routing-wildcard-download>

  // Capture the remaining path after the matched prefix.
  // doctag<routing-tail-segment>
  app.get('/static/**', (final req) {
    final relativeAssetPath = req.remainingPath.toString();

    return Response.ok(body: Body.fromString('Serve $relativeAssetPath'));
  });
  // end:doctag<routing-tail-segment>

  await app.serve();
}
