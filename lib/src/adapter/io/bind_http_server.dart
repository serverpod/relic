import 'dart:async';
import 'dart:io' as io;

/// Binds an HTTP server to the given address.
Future<io.HttpServer> bindHttpServer(
  final io.InternetAddress address, {
  final int port = 0,
  final io.SecurityContext? context,
  final int backlog = 0,
  final bool v6Only = false,
  final bool shared = false,
}) async {
  if (context == null) {
    return await io.HttpServer.bind(
      address,
      port,
      backlog: backlog,
      v6Only: v6Only,
      shared: shared,
    );
  }
  return await io.HttpServer.bindSecure(
    address,
    port,
    context,
    backlog: backlog,
    v6Only: v6Only,
    shared: shared,
  );
}
