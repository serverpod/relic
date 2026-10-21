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
  /// [address] defaults to [InternetAddress.loopbackIPv4]. [options] and
  /// [tls] go to [NativeAdapter.bind], and with [tls] the server speaks
  /// HTTPS.
  Future<RelicServer> serveNative({
    InternetAddress? address,
    int port = 8080,
    int noOfIsolates = 1,
    NativeOptions options = const NativeOptions(),
    NativeTls? tls,
  }) {
    final group = 'relic_native/$pid/${_serveCount++}';
    return run(
      () => NativeAdapter.bind(
        address ?? InternetAddress.loopbackIPv4,
        port: port,
        group: group,
        options: options,
        tls: tls,
      ),
      noOfIsolates: noOfIsolates,
    );
  }
}
