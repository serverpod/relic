import 'dart:io';

import 'package:relic/io_adapter.dart';
import 'package:relic/relic.dart';

Future<void> main() async {
  // Create a router that route all request to the same handler
  final router =
      RelicRouter()
        ..use('/', logRequests()) // log all request from / and down
        ..any(
          '/**',
          respondWith(
            (final request) =>
                Response.ok(body: Body.fromString('Hello, Relic!')),
          ),
        );

  // Start a server that forward request to the handler
  final server = RelicServer(
    () => IOAdapter.bind(InternetAddress.anyIPv4, port: 8080),
  );
  await server.mountAndStart(router.asHandler); // use asHandler to
}
