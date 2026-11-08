import 'dart:io';

import 'package:relic_core/relic_core.dart';
import 'package:relic_native/relic_native.dart';

var _groups = 0;

/// A started server on the loopback with [handler] mounted, and [options]
/// and [tls] on the adapter. [noOfIsolates] isolates share it through a
/// group of its own.
Future<RelicServer> serveNative(
  Handler handler, {
  InternetAddress? address,
  NativeOptions options = const NativeOptions(),
  NativeTls? tls,
  int noOfIsolates = 1,
}) async {
  final group = noOfIsolates > 1 ? 'relic_native/$pid/test/${_groups++}' : null;
  final server = RelicServer(
    () => NativeAdapter.bind(
      address ?? InternetAddress.loopbackIPv4,
      group: group,
      options: options,
      tls: tls,
    ),
    noOfIsolates: noOfIsolates,
  );
  await server.mountAndStart(handler);
  return server;
}

/// The head of a WebSocket opening handshake with the sample key of RFC
/// 6455 1.3, short of the empty line that ends it.
const webSocketUpgradeFields =
    'GET / HTTP/1.1\r\nHost: localhost\r\nUpgrade: websocket\r\n'
    'Connection: Upgrade\r\nSec-WebSocket-Version: 13\r\n'
    'Sec-WebSocket-Key: dGhlIHNhbXBsZSBub25jZQ==\r\n';
