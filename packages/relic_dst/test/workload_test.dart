import 'package:relic_core/relic_core.dart';
import 'package:relic_dst/relic_dst.dart';
import 'package:test/test.dart';

/// A server running the workload handler, with the contract watched.
Future<(RelicServer, ContractAdapter, SimAdapter)> _serve(
  final Simulation sim,
  final SimNetwork network, {
  final void Function()? onCancelled,
}) async {
  final adapter = SimAdapter.bind(
    network,
    idleTimeout: const Duration(seconds: 10),
    headerTimeout: const Duration(seconds: 2),
    drainTimeout: const Duration(seconds: 5),
    maxInlineBody: 64 << 10,
  );
  final contract = ContractAdapter(adapter, sim);
  final server = RelicServer(() => contract);
  await server.mountAndStart(workloadHandler(sim, onCancelled: onCancelled));
  return (server, contract, adapter);
}

Workload _workload(
  final Simulation sim,
  final SimNetwork network,
  final int port, {
  final int sessions = 16,
  final int actionsPerSession = 4,
}) => Workload(
  sim,
  network,
  port,
  sessions: sessions,
  actionsPerSession: actionsPerSession,
  headerTimeout: const Duration(seconds: 2),
  idleTimeout: const Duration(seconds: 10),
  maxInlineBody: 64 << 10,
);

/// The state the server must be in once every client is gone and the
/// last bytes have landed: no connection, every exchange ended, every
/// abandoned `/wait` seen as a cancellation, and the exchanges that
/// completed accounted for by the responses the clients read plus the
/// ones they never read.
Future<void> _expectSettled(
  final RelicServer server,
  final ContractAdapter contract,
  final Workload workload,
  final int cancelled,
) async {
  expect(await server.connectionsInfo(), (active: 0, closing: 0, idle: 0));
  expect(
    contract.exchanges.where((final e) => e.end == null),
    isEmpty,
    reason: 'every exchange has ended once its client is gone',
  );
  expect(cancelled, workload.abandonedWaits);
  final completed = contract.exchanges
      .where((final e) => e.end == ExchangeEnd.completed)
      .length;
  expect(completed, greaterThanOrEqualTo(workload.handlerResponses));
  expect(
    completed,
    lessThanOrEqualTo(workload.handlerResponses + workload.unreadCompletions),
  );
}

/// Runs [sessions] random client sessions against a workload server on
/// a network with [options], holds the server to its end state and closes it gracefully.
/// Every checked answer matches, the contract holds and nothing is left
/// pending.
Future<void> _expectWorkloadSettles(
  final Simulation sim, {
  required final NetworkOptions options,
  required final int sessions,
  required final int actionsPerSession,
}) async {
  final network = SimNetwork(sim, options: options);
  var cancelled = 0;
  final (server, contract, adapter) = await _serve(
    sim,
    network,
    onCancelled: () => cancelled++,
  );
  final workload = _workload(
    sim,
    network,
    adapter.port,
    sessions: sessions,
    actionsPerSession: actionsPerSession,
  );

  await workload.run();
  await sim.sleep(const Duration(seconds: 1));
  await _expectSettled(server, contract, workload, cancelled);
  final closing = sim.elapsed;
  await server.close();
  final closeTook = sim.elapsed - closing;
  await sim.sleep(const Duration(seconds: 1));

  expect(workload.checked, greaterThan(0));
  expect(contract.violations, isEmpty);
  expect(closeTook, Duration.zero, reason: 'nothing was left to drain');
  expectQuiescent(sim);
}

void main() {
  simProperty(
    'Given a workload server on a fragmenting network, '
    'when 16 random client sessions run and the server closes gracefully, '
    'then every checked answer matched, the contract held and nothing is '
    'left pending.',
    (final sim) => _expectWorkloadSettles(
      sim,
      options: const NetworkOptions(fragmentation: 0.5),
      sessions: 16,
      actionsPerSession: 4,
    ),
  );

  simTest(
    'Given a workload server on a fragmenting network, '
    'when 1000 random client sessions of 8 actions run and the server '
    'closes gracefully, '
    'then every checked answer matched, the contract held and nothing is '
    'left pending.',
    (final sim) => _expectWorkloadSettles(
      sim,
      options: const NetworkOptions(fragmentation: 0.5),
      sessions: 1000,
      actionsPerSession: 8,
    ),
    tags: 'soak',
  );

  simProperty(
    'Given a workload server on a network that resets one delivery in a '
    'thousand, '
    'when 16 random client sessions run and the server closes gracefully, '
    'then the contract held and nothing is left pending.',
    (final sim) async {
      final network = SimNetwork(
        sim,
        options: const NetworkOptions(resetProbability: 0.001),
      );
      final (server, contract, adapter) = await _serve(sim, network);
      final workload = _workload(sim, network, adapter.port);

      try {
        await workload.run();
      } on WorkloadFailure {
        // A reset in the middle of a checked exchange is the network's
        // doing. The server's conduct is what this scenario is about.
      } on SimConnectionReset {
        // Likewise.
      } on HttpParseException {
        // Likewise, for a response cut short.
      }
      await server.close();
      await sim.sleep(const Duration(seconds: 1));

      expect(contract.violations, isEmpty);
      expectQuiescent(sim);
    },
  );

  test('Given the workload with seed 5, '
      'when it runs twice, '
      'then both runs take the same actions and leave the same trace.', () {
    (List<(int, WorkloadAction)>, List<String>) run() {
      final sim = Simulation(seed: 5);
      late Workload workload;
      sim.run(() async {
        final network = SimNetwork(sim);
        final (server, _, adapter) = await _serve(sim, network);
        workload = _workload(sim, network, adapter.port);
        await workload.run();
        await server.close();
        await sim.sleep(const Duration(seconds: 1));
      });
      return (workload.taken, [for (final e in sim.trace) e.toString()]);
    }

    // Both from one call site: the core logs stack traces, which name it.
    final [(firstActions, firstTrace), (secondActions, secondTrace)] = [
      for (var i = 0; i < 2; i++) run(),
    ];

    expect(secondActions, firstActions);
    expect(secondTrace, firstTrace);
  });
}
