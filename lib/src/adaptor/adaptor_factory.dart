import 'dart:async';

import 'adaptor.dart';
import 'address.dart';
import 'io/io_adaptor_factory.dart';
import 'security_options.dart';

/// Factory for creating adaptors based on the current platform
abstract class AdaptorFactory {
  /// Create an adaptor
  ///
  /// This will create the appropriate adaptor implementation
  /// based on the current platform.
  static Future<Adaptor> create({
    required final Address address,
    required final int port,
    final SecurityOptions? security,
    final int? backlog,
    final bool shared = false,
  }) {
    // The import mechanism above will determine the right implementation
    return createIOAdaptor(
      address: address,
      port: port,
      security: security,
      backlog: backlog,
      shared: shared,
    );
  }
}
