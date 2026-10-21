import 'dart:io';

import 'package:relic_core/relic_core.dart';
import 'package:relic_native/relic_native.dart';

/// A started server on the loopback with [handler] mounted, and [options]
/// and [tls] on the adapter.
Future<RelicServer> serveNative(
  Handler handler, {
  InternetAddress? address,
  NativeOptions options = const NativeOptions(),
  NativeTls? tls,
}) async {
  final server = RelicServer(
    () => NativeAdapter.bind(
      address ?? InternetAddress.loopbackIPv4,
      options: options,
      tls: tls,
    ),
  );
  await server.mountAndStart(handler);
  return server;
}
