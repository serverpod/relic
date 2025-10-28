import 'dart:async';
import 'dart:io';

import '../../../relic.dart';
import 'io_adapter.dart';

extension RelicAppIOServeEx on RelicApp {
  /// Starts a [HttpServer] that listens on the specified [address] and
  /// [port] and sends requests to [handler].
  ///
  /// If [securityContext] is provided, a secure HTTPS server will be started
  /// using [HttpServer.bindSecure]. Otherwise, an HTTP server will be started
  /// using [HttpServer.bind].
  ///
  /// If not specified [address] will default to [InternetAddress.loopbackIPv4],
  /// and [port] to 8080.
  Future<RelicServer> serve({
    final InternetAddress? address,
    final int port = 8080,
    final SecurityContext? securityContext,
    final int backlog = 0,
    final bool shared = false,
  }) {
    return run(
      () => IOAdapter.bind(
        address ?? InternetAddress.loopbackIPv4,
        port: port,
        context: securityContext,
        backlog: backlog,
        shared: shared,
      ),
    );
  }
}
