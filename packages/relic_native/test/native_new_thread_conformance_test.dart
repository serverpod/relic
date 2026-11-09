import 'package:relic_core/relic_core.dart';
import 'package:relic_native/src/native_adapter.dart'
    show debugTickOnNewThreads;
import 'package:test_utils/adapter_conformance.dart';

import 'native_test_helpers.dart';

/// The suite with every reactor tick on a native thread that exits after
/// it, as when the Dart VM retires the thread an isolate ran on between
/// two turns.
void main() {
  adapterConformance(
    'NativeAdapter ticking on new threads',
    bind: conformanceBind(
      'new-threads',
      inIsolate: () => debugTickOnNewThreads = true,
    ),
    capabilities: const AdapterCapabilities(hijack: true, webSocket: true),
  );
}
