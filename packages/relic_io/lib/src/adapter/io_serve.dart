import 'dart:async';
import 'dart:io';

import 'package:relic_core/relic_core.dart';
import 'io_adapter.dart';

extension RelicAppIOServeEx on RelicApp {
  /// Starts a [HttpServer] that listens on the specified [address] and
  /// [port] and sends requests to [handler].
  ///
  /// If [securityContext] is provided, a secure HTTPS server will be started
  /// using [HttpServer.bindSecure]. Otherwise, an HTTP server will be started
  /// using [HttpServer.bind].
  ///
  /// The maximum length of the queue for incoming connections is specified by
  /// [backlog]. Defaults to 0 (system-dependent)
  ///
  /// The [v6Only] parameter controls whether an IPv6 socket accepts only IPv6
  /// connections (ignored for IPv4 addresses).
  ///
  /// The [noOfIsolates] parameter specifies the number of isolates to spawn
  /// for handling requests. When greater than 1, [shared] is automatically
  /// enabled to allow multiple isolates to bind to the same port.
  ///
  /// If not specified [address] will default to [InternetAddress.loopbackIPv4],
  /// and [port] to 8080.
  Future<RelicServer> serve({
    final InternetAddress? address,
    final int port = 8080,
    final SecurityContext? securityContext,
    final int backlog = 0,
    final bool v6Only = false,
    final bool shared = false,
    final int noOfIsolates = 1,
  }) {
    return run(
      () => IOAdapter.bind(
        address ?? InternetAddress.loopbackIPv4,
        port: port,
        context: securityContext,
        backlog: backlog,
        v6Only: v6Only,
        shared: shared || noOfIsolates > 1,
      ),
      noOfIsolates: noOfIsolates,
    );
  }
}
