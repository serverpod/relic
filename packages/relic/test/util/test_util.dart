import 'dart:io';

import 'package:relic/relic.dart';
import 'package:test/test.dart';

// Re-export shared test utilities from relic_core
export 'package:relic_core/src/test/test_util.dart';

final isOhNoStateError = isA<StateError>().having(
  (final e) => e.message,
  'message',
  'oh no',
);

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
