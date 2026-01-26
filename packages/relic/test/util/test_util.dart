import 'dart:io';

import 'package:relic/relic.dart';

Future<RelicServer> testServe(
  final Handler handler, {
  final SecurityContext? context,
}) async {
  final server = RelicServer(
    () =>
        IOAdapter.bind(InternetAddress.loopbackIPv4, port: 0, context: context),
  );
  await server.mountAndStart(handler);
  return server;
}
