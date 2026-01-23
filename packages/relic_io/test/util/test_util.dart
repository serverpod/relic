import 'dart:io';

import 'package:relic_core/relic_core.dart';
import 'package:relic_io/relic_io.dart';

// Re-export shared test utilities from relic_core
export '../util/test_util.dart';

/// Extension methods for RelicServer
extension RelicServerTestEx on RelicServer {
  /// Fake [url] property for the [RelicServer] for testing purposes.
  ///
  /// In general a server cannot know what URL it is being accessed by before an
  /// actual request arrives, but for testing purposes we can infer a local URL
  /// based on the server's port.
  Uri get url => Uri.http('localhost:$port');
}

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
