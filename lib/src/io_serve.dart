import 'dart:async';
import 'dart:io';

import 'adapter/io/bind_http_server.dart';
import 'adapter/io/io_adapter.dart';
import 'handler/handler.dart';
import 'relic_server.dart';

/// Starts a server that listens on the specified [address] and
/// [port] and sends requests to [handler].
///
/// If [security] is provided, a secure server will be started.
///
/// {@template relic_server_header_defaults}
/// Every response will get a "date" header and an "X-Powered-By" header.
/// If either header is present in the `Response`, it will not be
/// overwritten.
/// Pass [poweredByHeader] to set the default content for "X-Powered-By",
/// pass `null` to omit this header.
/// {@endtemplate}
Future<RelicServer> serve(
  final Handler handler,
  final InternetAddress address,
  final int port, {
  final SecurityContext? context,
  final int? backlog,
  final bool shared = false,
  final bool strictHeaders = false,
  final String? poweredByHeader,
}) async {
  final adapter = IOAdapter(await bindHttpServer(
    address,
    port: port,
    context: context,
    backlog: backlog ?? 0,
    shared: shared,
  ));
  final server = RelicServer(
    adapter,
    strictHeaders: strictHeaders,
    poweredByHeader: poweredByHeader,
  );
  await server.mountAndStart(handler);
  return server;
}
