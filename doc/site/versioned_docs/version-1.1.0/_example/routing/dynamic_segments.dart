import 'package:relic/relic.dart';

// doctag<routing-custom-path-param>
/// A reusable path parameter accessor for [DateTime] values.
final class DateTimePathParam extends PathParam<DateTime> {
  const DateTimePathParam(final Symbol key) : super(key, DateTime.parse);
}

// Usage:
const dateParam = DateTimePathParam(#date);
// In a handler: request.pathParameters.get(dateParam) returns DateTime
// end:doctag<routing-custom-path-param>

// doctag<routing-custom-path-param-inline>
// Custom enum parameter
const statusParam = PathParam<Status>(#status, Status.parse);

// Custom object parameter
const createdParam = PathParam<DateTime>(#date, DateTime.parse);
// end:doctag<routing-custom-path-param-inline>

// Dummy Status class for documentation purposes.
enum Status {
  active,
  inactive;

  static Status parse(final String value) => Status.values.byName(value);
}

/// Examples demonstrating how Relic handles dynamic path segments.
Future<void> main() async {
  final app = RelicApp();

  // Capture a named path parameter and read it from the request.
  // doctag<routing-path-params-id>
  app.get('/users/:id', (final req) {
    final userId = req.pathParameters.raw[#id];

    return Response.ok(body: Body.fromString('User $userId'));
  });
  // end:doctag<routing-path-params-id>

  // Use typed path parameters for automatic parsing.
  // doctag<routing-typed-path-params>
  // Define typed parameter accessors
  const idParam = IntPathParam(#id);
  const latParam = DoublePathParam(#lat);
  const lonParam = DoublePathParam(#lon);

  app.get('/users/:id', (final Request request) {
    // Automatically parsed as int (throws if missing or invalid)
    final userId = request.pathParameters.get(idParam);
    return Response.ok(body: Body.fromString('User $userId'));
  });

  app.get('/location/:lat/:lon', (final Request request) {
    // Automatically parsed as double (throws if missing or invalid)
    final lat = request.pathParameters.get(latParam);
    final lon = request.pathParameters.get(lonParam);
    return Response.ok(body: Body.fromString('Location: $lat, $lon'));
  });
  // end:doctag<routing-typed-path-params>

  // doctag<routing-typed-path-params-nullable>
  app.get('/optional/:id', (final Request request) {
    final userId = request.pathParameters(idParam); // int? - null if missing
    return Response.ok(body: Body.fromString('User: $userId'));
  });
  // end:doctag<routing-typed-path-params-nullable>

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
