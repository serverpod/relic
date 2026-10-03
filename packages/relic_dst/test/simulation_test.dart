import 'dart:async';

import 'package:clock/clock.dart';
import 'package:relic_dst/relic_dst.dart';
import 'package:test/test.dart';

void main() {
  test(
    'Given timers at 300 ms, 100 ms and 200 ms, '
    'when the simulation runs, '
    'then they fire in order of their due time and the clock jumps to each.',
    () {
      final sim = Simulation(seed: 1);
      final fired = <(String, Duration)>[];

      sim.run(() async {
        Timer(
          const Duration(milliseconds: 300),
          () => fired.add(('c', sim.elapsed)),
        );
        Timer(
          const Duration(milliseconds: 100),
          () => fired.add(('a', sim.elapsed)),
        );
        Timer(
          const Duration(milliseconds: 200),
          () => fired.add(('b', sim.elapsed)),
        );
        await Future<void>.delayed(const Duration(milliseconds: 300));
      });

      expect(fired, [
        ('a', const Duration(milliseconds: 100)),
        ('b', const Duration(milliseconds: 200)),
        ('c', const Duration(milliseconds: 300)),
      ]);
    },
  );

  test('Given a body that sleeps for an hour of simulated time, '
      'when the simulation runs, '
      'then it completes at once and clock.now() has moved by an hour.', () {
    final sim = Simulation(seed: 1, maxElapsed: const Duration(hours: 2));
    final watch = Stopwatch()..start();

    final seen = sim.run(() async {
      final start = clock.now();
      await Future<void>.delayed(const Duration(hours: 1));
      return clock.now().difference(start);
    });

    expect(seen, const Duration(hours: 1));
    expect(sim.now, sim.epoch.add(const Duration(hours: 1)));
    expect(watch.elapsed, lessThan(const Duration(seconds: 5)));
  });

  test('Given a microtask and a zero timer scheduled together, '
      'when the simulation runs, '
      'then the microtask runs first.', () {
    final sim = Simulation(seed: 1);
    final order = <String>[];

    sim.run(() async {
      Timer.run(() => order.add('timer'));
      scheduleMicrotask(() => order.add('microtask'));
      await Future<void>.delayed(Duration.zero);
    });

    expect(order, ['microtask', 'timer']);
  });

  test('Given a periodic timer of 10 ms, '
      'when the body waits 35 ms and cancels it, '
      'then it fired three times and no timer is left pending.', () {
    final sim = Simulation(seed: 1);
    var ticks = 0;

    sim.run(() async {
      final timer = Timer.periodic(const Duration(milliseconds: 10), (_) {
        ticks++;
      });
      await Future<void>.delayed(const Duration(milliseconds: 35));
      timer.cancel();
    });

    expect(ticks, 3);
    expect(sim.pendingTimers, 0);
  });

  test('Given a periodic timer with a zero period, '
      'when the body waits 1 ms and cancels it, '
      'then it fired once per microsecond and the clock moved on.', () {
    final sim = Simulation(seed: 1);
    var ticks = 0;

    sim.run(() async {
      final timer = Timer.periodic(Duration.zero, (_) {
        ticks++;
      });
      await Future<void>.delayed(const Duration(milliseconds: 1));
      timer.cancel();
    });

    expect(ticks, 1000);
    expect(sim.elapsed, const Duration(milliseconds: 1));
  });

  test('Given a body that awaits a future nothing completes, '
      'when the simulation runs, '
      'then it fails with SimulationStalled.', () {
    final sim = Simulation(seed: 1);

    expect(
      () => sim.run(() => Completer<void>().future),
      throwsA(isA<SimulationStalled>()),
    );
  });

  test('Given a body that throws after a delay, '
      'when the simulation runs, '
      'then run rethrows the error.', () {
    final sim = Simulation(seed: 1);

    expect(
      () => sim.run(() async {
        await Future<void>.delayed(const Duration(seconds: 1));
        throw StateError('oh no');
      }),
      throwsA(isA<StateError>()),
    );
  });

  test('Given a timer due past maxElapsed, '
      'when the simulation runs, '
      'then it fails with SimulationOverrun.', () {
    final sim = Simulation(seed: 1, maxElapsed: const Duration(seconds: 1));

    expect(
      () => sim.run(() => Future<void>.delayed(const Duration(seconds: 2))),
      throwsA(isA<SimulationOverrun>()),
    );
  });

  test('Given two simulations with the same seed, '
      'when each draws random numbers between random delays, '
      'then they draw the same numbers.', () {
    List<int> draw() {
      final sim = Simulation(seed: 42);
      return sim.run(() async {
        final out = <int>[];
        for (var i = 0; i < 10; i++) {
          await Future<void>.delayed(
            Duration(milliseconds: sim.random.nextInt(100)),
          );
          out.add(sim.random.nextInt(1 << 20));
        }
        return out;
      });
    }

    expect(draw(), draw());
  });

  test('Given a body that prints, '
      'when the simulation runs, '
      'then the line is recorded in printed and the trace.', () {
    final sim = Simulation(seed: 1);

    // ignore: avoid_print
    sim.run(() => print('hello'));

    expect(sim.printed, ['hello']);
    expect(sim.trace.single.message, 'hello');
    expect(sim.trace.single.category, 'print');
  });
}
