import 'dart:io';
import 'dart:typed_data';

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

/// A WebSocket opening handshake, [webSocketUpgradeFields] and the empty
/// line.
const webSocketUpgradeRequest = '$webSocketUpgradeFields\r\n';

/// The Sec-WebSocket-Accept that answers the key of
/// [webSocketUpgradeFields].
const webSocketUpgradeAccept = 's3pPLMBiTxaQ9kYGzzhZRbK+xOo=';

/// Closes [socket] with a reset everywhere but Windows, so the server's
/// next write to it fails.
///
/// SO_LINGER on with a zero timeout. Its struct is two ints, or two
/// u_shorts on Windows. dart:io on Windows shuts a socket down and
/// disconnects it before it closes it (ClientSocket::DoCloseLocked in the
/// SDK's runtime/bin/eventhandler_win.cc), so the server sees a FIN there
/// and its first write still goes out.
void resetConnection(Socket socket) {
  final (option, linger) = switch (Platform.operatingSystem) {
    'linux' || 'android' => (13, Uint8List(8)),
    'windows' => (0x80, Uint8List(4)),
    _ => (0x80, Uint8List(8)),
  };
  linger[0] = 1;
  socket.setRawOption(
    RawSocketOption(RawSocketOption.levelSocket, option, linger),
  );
  socket.destroy();
}
