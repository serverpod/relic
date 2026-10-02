import 'dart:io';

import 'package:relic_core/relic_core.dart';
import 'package:relic_native/relic_native.dart';

/// A started server on the loopback with [handler] mounted, with whichever
/// adapter options a test sets.
Future<RelicServer> serveNative(
  Handler handler, {
  InternetAddress? address,
  int maxInlineBody = 1 << 20,
  int maxConnections = 0,
  Duration idleTimeout = const Duration(seconds: 60),
  Duration headerTimeout = const Duration(seconds: 10),
  Duration bodyTimeout = const Duration(seconds: 30),
  Duration writeTimeout = const Duration(seconds: 30),
}) async {
  final server = RelicServer(
    () => NativeAdapter.bind(
      address ?? InternetAddress.loopbackIPv4,
      maxInlineBody: maxInlineBody,
      maxConnections: maxConnections,
      idleTimeout: idleTimeout,
      headerTimeout: headerTimeout,
      bodyTimeout: bodyTimeout,
      writeTimeout: writeTimeout,
    ),
  );
  await server.mountAndStart(handler);
  return server;
}
