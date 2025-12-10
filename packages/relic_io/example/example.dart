import 'dart:io';

import 'package:relic_core/relic_core.dart';
import 'package:relic_io/relic_io.dart';

/// Example demonstrating relic_io's dart:io server binding.
Future<void> main() async {
  final handler = const Pipeline()
      .addMiddleware(logRequests())
      .addHandler((_) => Response.ok(body: Body.fromString('Hello!')));

  // Create server with IOAdapter factory
  final server = RelicServer(
    () => IOAdapter.bind(InternetAddress.loopbackIPv4, port: 8080),
  );

  await server.mountAndStart(handler);
  print('Serving at http://localhost:${server.port}');
}
