import 'dart:async';
import 'dart:io' as io;

/// Binds an HTTP server to the given [address] and [port].
///
/// If [context] is provided, a secure HTTPS server will be started using
/// [io.HttpServer.bindSecure]. Otherwise, an HTTP server will be started
/// using [io.HttpServer.bind].
///
/// - [address]: The [io.InternetAddress] to bind the server to.
/// - [port]: The port number to listen on. Defaults to 0, which means
///   the operating system will assign an available port.
/// - [context]: An optional [io.SecurityContext] for HTTPS. If null, HTTP is used.
/// - [backlog]: The maximum length of the queue for incoming connections.
///   Defaults to 0 (system-dependent).
/// - [v6Only]: Whether to only accept IPv6 connections. This is only
///   meaningful for IPv6 addresses. Defaults to false.
/// - [shared]: Whether to allow multiple `HttpServer` objects to bind to the
///   same combination of [address], [port] and [v6Only]. Defaults to false.
///
/// Returns a [Future] that completes with the bound [io.HttpServer].
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
