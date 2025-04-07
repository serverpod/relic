import 'dart:async';

import 'address_type.dart';
import 'io/io_implementation.dart';
import 'security_options.dart';
import 'server_adaptor.dart';

/// Factory for creating server adaptors based on the current platform
abstract class ServerAdaptorFactory {
  /// Create a server adaptor
  ///
  /// This will create the appropriate server adaptor implementation
  /// based on the current platform.
  static Future<ServerAdaptor> create({
    required final Address address,
    required final int port,
    final SecurityOptions? security,
    final int? backlog,
    final bool shared = false,
  }) {
    // The import mechanism above will determine the right implementation
    return createServerAdaptor(
      address: address,
      port: port,
      security: security,
      backlog: backlog,
      shared: shared,
    );
  }
}
