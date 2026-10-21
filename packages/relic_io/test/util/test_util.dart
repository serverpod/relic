import 'dart:io';

import 'package:relic_core/relic_core.dart';
import 'package:relic_io/relic_io.dart';

// Re-export shared test utilities from relic_core
export '../util/test_util.dart';

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
