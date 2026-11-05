import 'dart:io';

import 'package:relic_core/relic_core.dart';
import 'package:relic_native/relic_native.dart';
import 'package:test_utils/adapter_conformance.dart';

var _groups = 0;

void main() {
  adapterConformance(
    'NativeAdapter',
    bind:
        ({
          required InternetAddress address,
          int port = 0,
          bool v6Only = false,
          bool shared = false,
        }) {
          // One group per server, minted when the suite asks for the factory,
          // so the isolates of one server share it and two servers never do.
          final group = shared ? 'conformance/$pid/${_groups++}' : null;
          return () => NativeAdapter.bind(
            address,
            port: port,
            v6Only: v6Only,
            group: group,
          );
        },
    capabilities: const AdapterCapabilities(hijack: true, webSocket: true),
  );
}
