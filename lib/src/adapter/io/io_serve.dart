import 'dart:async';
import 'dart:io';

import '../../../relic.dart';
import 'io_adapter.dart';

extension RelicAppIOServeEx on RelicApp {
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
  Future<RelicServer> serve({
    final InternetAddress? address,
    final int port = 8080,
    final SecurityContext? securityContext,
    final int backlog = 0,
    final bool shared = false,
  }) {
    return run(() => IOAdapter.bind(
          // expose on loopback interface by default
          address ?? InternetAddress.loopbackIPv4,
          port: port,
          context: securityContext,
          backlog: backlog,
          shared: shared,
        ));
  }
}
