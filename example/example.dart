// ignore_for_file: avoid_print
import 'package:relic/relic.dart';

void main() async {
  final handler =
      const Pipeline().addMiddleware(logRequests()).addHandler(_echoRequest);

  final server = await serve(
    handler,
    Address.loopback(),
    8080,
  );

  print('Serving at http://${server.adaptor.address}:${server.adaptor.port}');
}

Response _echoRequest(final Request request) {
  return Response.ok(
    body: Body.fromString(
      'Request for "${request.url}"',
    ),
  );
}
