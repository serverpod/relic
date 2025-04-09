// ignore_for_file: avoid_print
import 'package:relic/relic.dart';

void main() async {
  final handler =
      const Pipeline().addMiddleware(logRequests()).addHandler(_echoRequest);

  final server = await serve(
    handler,
    InternetAddress.loopbackIPv4,
    8080,
  );

  // Enable content compression
  server.autoCompress = true;

  print('Serving at http://${server.address.host}:${server.port}');
}

Response _echoRequest(final Request request) {
  return Response.ok(
    body: Body.fromString(
      'Request for "${request.url}"',
    ),
  );
}
