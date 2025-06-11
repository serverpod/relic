import 'package:meta/meta.dart';

import '../ip_address/ip_address.dart';

typedef _SocketAddressRecord = ({IPAddress address, int port});

// ignore: library_private_types_in_public_api
extension type const SocketAddress._(_SocketAddressRecord record) {
  static const int maxPort = (1 << 16) - 1;

  factory SocketAddress({
    required final IPAddress address,
    required final int port,
  }) {
    if (port < 0 || port > maxPort) {
      throw ArgumentError.value(
        port,
        'port',
        'Port must be between 0 and $maxPort (inclusive).',
      );
    }
    return SocketAddress._((address: address, port: port));
  }

  static final none = SocketAddress._((address: IPv6Address.any, port: 0));

  IPAddress get address => record.address;
  int get port => record.port;

  bool get isWellKnownPort => port < 1024;

  String get display {
    final addressString =
        address is IPv6Address ? '[$address]' : address.toString();
    return '$addressString:$port';
  }
}

/// Represents the connection information of a network request.
/// Can be HTTP but also other types of network connections.
@immutable
class ConnectionInfo {
  /// The remote [SocketAddress] of the IP connection
  final SocketAddress remote;

  /// The local network port of the IP connection.
  final int localPort;

  /// Creates a [ConnectionInfo] object.
  const ConnectionInfo({required this.remote, required this.localPort});

  static final empty = ConnectionInfo(remote: SocketAddress.none, localPort: 0);

  @override
  String toString() {
    return 'ConnectionInfo(remote: ${remote.display}, local port:$localPort)';
  }
}
