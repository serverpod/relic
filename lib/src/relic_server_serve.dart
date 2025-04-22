import 'dart:async';

import 'adaptor/address.dart';
import 'adaptor/security_options.dart';
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
  final Address address,
  final int port, {
  final SecurityOptions? security,
  final int? backlog,
  final bool shared = false,
  final bool strictHeaders = false,
  final String? poweredByHeader,
}) async {
  final server = await RelicServer.createServer(
    address,
    port,
    security: security,
    backlog: backlog,
    shared: shared,
    strictHeaders: strictHeaders,
    poweredByHeader: poweredByHeader,
  );

  await server.mountAndStart(handler);
  return server;
}
