/// Deterministic simulation testing for Relic adapters.
///
/// A [Simulation] runs asynchronous code with a virtual clock and a seeded
/// random, a [SimNetwork] carries bytes between a [SimAdapter] and
/// [SimHttpClient]s with latency, fragmentation and faults, and a
/// [ContractAdapter] watches the adapter boundary. [simTest] and
/// [simProperty] put a scenario in a test, replayable from its seed.
library;

export 'src/contract.dart';
export 'src/dst_test.dart';
export 'src/http1.dart';
export 'src/sim_adapter.dart';
export 'src/sim_client.dart';
export 'src/sim_network.dart';
export 'src/simulation.dart';
export 'src/workload.dart';
