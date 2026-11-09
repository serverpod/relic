import 'package:relic_core/relic_core.dart';
import 'package:test_utils/adapter_conformance.dart';

import 'native_test_helpers.dart';

void main() {
  adapterConformance(
    'NativeAdapter',
    bind: conformanceBind('conformance'),
    capabilities: const AdapterCapabilities(hijack: true, webSocket: true),
  );
}
