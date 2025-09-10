import 'dart:async';
import 'dart:io';

import '../../handler/handler.dart';
import '../../relic_server.dart';
import 'bind_http_server.dart';
import 'io_adapter.dart';

/// Starts a server that listens on the specified [address] and
/// [port] and sends requests to [handler].
///
/// If [securityContext] is provided, a secure server will be started.
///
/// {@template relic_server_header_defaults}
/// Every response will get a "date" header.
/// If this header is present in the `Response`, it will not be
/// overwritten.
/// {@endtemplate}
Future<RelicServer> serve(
  final Handler handler,
  final InternetAddress address,
  final int port, {
  final SecurityContext? securityContext,
  final int? backlog,
  final bool shared = false,
}) async {
  final adapter = IOAdapter(await bindHttpServer(
    address,
    port: port,
    context: securityContext,
    backlog: backlog ?? 0,
    shared: shared,
  ));
  final server = RelicServer(adapter);
  await server.mountAndStart(handler);
  return server;
}
