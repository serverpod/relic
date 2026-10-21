import 'dart:io';

import 'package:relic_core/relic_core.dart';
import 'package:relic_io/relic_io.dart';
import 'package:test_utils/adapter_conformance.dart';

void main() {
  adapterConformance(
    'IOAdapter',
    bind: ({bool shared = false}) =>
        () => IOAdapter.bind(
          InternetAddress.loopbackIPv4,
          port: 0,
          shared: shared,
        ),
    capabilities: const AdapterCapabilities(hijack: true, webSocket: true),
    // dart:io reports a gone peer only as an error after a write, swallows
    // a lost connection under addStream, and its parser has eaten what
    // followed the body before the socket is detached.
    seesPeerGone: false,
    failsRespondMidStream: false,
    keepsPipelinedBytes: false,
  );
}
