import 'dart:io';

import 'package:relic_core/relic_core.dart';

import 'native_adapter.dart';

var _serveCount = 0;

extension RelicAppNativeServeEx on RelicApp {
  /// Starts a native server on [address] and [port] that sends requests to
  /// this app.
  ///
  /// [noOfIsolates] isolates handle requests and share one native server,
  /// bound once. Each call mints its own group, so two calls never share a
  /// server and port 0 works with several isolates.
  ///
  /// If not specified [address] defaults to [InternetAddress.loopbackIPv4]
  /// and [port] to 8080.
  /// The timeouts and [maxConnections] are those of [NativeAdapter.bind].
  Future<RelicServer> serveNative({
    InternetAddress? address,
    int port = 8080,
    int noOfIsolates = 1,
    int backlog = 128,
    int maxConnections = 0,
    Duration idleTimeout = const Duration(seconds: 60),
    Duration headerTimeout = const Duration(seconds: 10),
    Duration bodyTimeout = const Duration(seconds: 30),
    Duration writeTimeout = const Duration(seconds: 30),
  }) {
    final group = 'relic_native/$pid/${_serveCount++}';
    return run(
      () => NativeAdapter.bind(
        address ?? InternetAddress.loopbackIPv4,
        port: port,
        group: group,
        backlog: backlog,
        maxConnections: maxConnections,
        idleTimeout: idleTimeout,
        headerTimeout: headerTimeout,
        bodyTimeout: bodyTimeout,
        writeTimeout: writeTimeout,
      ),
      noOfIsolates: noOfIsolates,
    );
  }
}
