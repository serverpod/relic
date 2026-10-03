import 'dart:async';
import 'dart:io' show Platform;

import 'package:meta/meta.dart';
import 'package:test/test.dart';

import 'simulation.dart';

/// The seed `DST_SEED` pins a run to, or null.
int? get pinnedSeed => int.tryParse(Platform.environment['DST_SEED'] ?? '');

/// The seed a [simTest] runs with: `DST_SEED`, or 1.
int get defaultSeed => pinnedSeed ?? 1;

/// How many seeds a [simProperty] runs: `DST_SEEDS`, or 20.
int get defaultSeedCount =>
    int.tryParse(Platform.environment['DST_SEEDS'] ?? '') ?? 20;

/// Runs [body] in a fresh [Simulation] seeded with [seed]. When it fails,
/// the seed and the tail of the trace go out with the failure.
void runSimulation(
  final int seed,
  final FutureOr<void> Function(Simulation sim) body, {
  final Duration maxElapsed = const Duration(hours: 1),
  final int traceTail = 200,
}) {
  final sim = Simulation(seed: seed, maxElapsed: maxElapsed);
  try {
    sim.run(() => body(sim));
  } catch (_) {
    printOnFailure(sim.dump(tail: traceTail));
    rethrow;
  }
}

/// A test whose body runs inside a [Simulation].
///
/// The body awaits simulated time, not real time, and the test finishes
/// as soon as the body does. `DST_SEED` overrides [seed].
@isTest
void simTest(
  final String description,
  final FutureOr<void> Function(Simulation sim) body, {
  final int? seed,
  final Duration maxElapsed = const Duration(hours: 1),
  final Object? skip,
  final Object? tags,
}) {
  test(
    description,
    () => runSimulation(seed ?? defaultSeed, body, maxElapsed: maxElapsed),
    skip: skip,
    tags: tags,
  );
}

/// A test whose body runs once per seed, from [firstSeed] for [seeds]
/// seeds. The first failing seed fails the test with its trace.
///
/// `DST_SEED` runs that seed alone, which is how a failure is replayed,
/// and `DST_SEEDS` sets how many seeds run otherwise.
@isTest
void simProperty(
  final String description,
  final FutureOr<void> Function(Simulation sim) body, {
  final int? seeds,
  final int firstSeed = 1,
  final Duration maxElapsed = const Duration(hours: 1),
  final Object? skip,
}) {
  test(description, () {
    final pinned = pinnedSeed;
    final count = seeds ?? defaultSeedCount;
    final run = pinned != null
        ? [pinned]
        : [for (var i = 0; i < count; i++) firstSeed + i];
    for (final seed in run) {
      runSimulation(seed, body, maxElapsed: maxElapsed);
    }
  }, skip: skip);
}

/// Fails unless nothing is left in the simulation: no timer and no
/// event. What a clean shutdown leaves behind.
void expectQuiescent(final Simulation sim) {
  expect(
    sim.pendingTimers,
    0,
    reason: 'timers left pending after the scenario ended',
  );
  expect(
    sim.pendingEvents,
    0,
    reason: 'network events left pending after the scenario ended',
  );
}
