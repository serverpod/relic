import 'dart:io';

import 'package:relic/relic.dart';

Future<RelicServer> testServe(
  Handler handler, {
  SecurityContext? context,
}) async {
  final server = RelicServer(
    () =>
        IOAdapter.bind(InternetAddress.loopbackIPv4, port: 0, context: context),
  );
  await server.mountAndStart(handler);
  return server;
}
