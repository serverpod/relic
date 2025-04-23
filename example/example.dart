// ignore_for_file: avoid_print
import 'dart:io';

import 'package:relic/relic.dart';

void main() async {
  final handler =
      const Pipeline().addMiddleware(logRequests()).addHandler(_echoRequest);

  await serve(
    handler,
    InternetAddress.anyIPv4,
    8080,
  );
}

Response _echoRequest(final Request request) {
  return Response.ok(
    body: Body.fromString(
      'Request for "${request.url}"',
    ),
  );
}
