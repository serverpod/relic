import 'package:relic/relic.dart';
import 'package:relic/src/address/relic_address.dart';

void main() async {
  var handler =
      const Pipeline().addMiddleware(logRequests()).addHandler(_echoRequest);

  var server = await serve(
    handler,
    RelicAddress.fromString(address: 'localhost', port: 8080),
  );

  // Enable content compression
  server.autoCompress = true;

  print('Serving at http://${server.address.host}:${server.port}');
}

Response _echoRequest(Request request) {
  return Response.ok(
    body: Body.fromString(
      'Request for "${request.url}"',
    ),
  );
}
