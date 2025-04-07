import 'dart:async';
import 'dart:io' as io;

import '../address_type.dart';
import '../security_options.dart';
import '../server_adaptor.dart';
import 'io_server_adaptor.dart';

/// Create an IO server adaptor
///
/// This function is used by the ServerAdaptorFactory when running on platforms
/// that support dart:io.
Future<ServerAdaptor> createServerAdaptor({
  required final Address address,
  required final int port,
  final SecurityOptions? security,
  final int? backlog,
  final bool shared = false,
}) async {
  // Convert AddressType to io.InternetAddress
  final ioAddress = io.InternetAddress(address.address);

  final server = security == null
      ? await io.HttpServer.bind(
          ioAddress,
          port,
          backlog: backlog ?? 0,
          shared: shared,
        )
      : await io.HttpServer.bindSecure(
          ioAddress,
          port,
          security.context as io.SecurityContext,
          backlog: backlog ?? 0,
          shared: shared,
        );

  return IOServerAdaptor(server);
}
