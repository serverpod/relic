import 'package:meta/meta.dart';

import 'ip_address.dart';

/// Represents the connection information of a network request.
/// Can be HTTP but also other types of network connections.
@immutable
class ConnectionInfo {
  /// The internet address of the connected client.
  final IPAddress remoteAddress;

  /// The remote network port of the connected client.
  final int remotePort;

  /// The local network port of the client connection.
  final int localPort;

  /// Creates a [ConnectionInfo] object.
  const ConnectionInfo({
    required this.remoteAddress,
    required this.remotePort,
    required this.localPort,
  });

  /// A [ConnectionInfo] object representing an unknown connection.
  ConnectionInfo.unknown()
      : this(
          remoteAddress: IPv6Address.any,
          remotePort: 0,
          localPort: 0,
        );

  @override
  String toString() {
    return 'ConnectionInfo(remote: ${remoteAddress is IPv6Address ? '[$remoteAddress]' : remoteAddress}:$remotePort, local port:$localPort)';
  }
}
