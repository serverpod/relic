import 'dart:async';
import 'dart:io' as io;

import '../adaptor.dart';
import '../address.dart';
import '../security_options.dart';
import 'io_adaptor.dart';

/// Create an IO adaptor
Future<Adaptor> createIOAdaptor({
  required final Address address,
  required final int port,
  final SecurityOptions? security,
  final int? backlog,
  final bool shared = false,
}) async {
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

  return IOAdaptor(server);
}
