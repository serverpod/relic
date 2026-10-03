import 'dart:async';
import 'dart:collection';
import 'dart:math';

import 'package:clock/clock.dart';

/// One line of a [Simulation]'s trace.
final class TraceEntry {
  final Duration at;
  final String category;
  final String message;

  const TraceEntry(this.at, this.category, this.message);

  @override
  String toString() => '${formatElapsed(at)} $category: $message';
}

/// Simulated time as seconds with microsecond precision.
String formatElapsed(final Duration elapsed) {
  final seconds = elapsed.inMicroseconds / Duration.microsecondsPerSecond;
  return '${seconds.toStringAsFixed(6)}s';
}

/// The body of [Simulation.run] has not completed, and no timer, event
/// or microtask is left that could complete it.
final class SimulationStalled extends Error {
  final Duration at;

  SimulationStalled(this.at);

  @override
  String toString() =>
      'The simulation stalled at ${formatElapsed(at)}: the body has not '
      'completed and nothing is pending';
}

/// The next event is due past [Simulation.maxElapsed].
final class SimulationOverrun extends Error {
  final Duration due;
  final Duration limit;

  SimulationOverrun(this.due, this.limit);

  @override
  String toString() =>
      'The simulation ran past its bound of ${formatElapsed(limit)}: the '
      'next event is due at ${formatElapsed(due)}';
}

/// A deterministic run of asynchronous Dart code.
///
/// Everything that would otherwise come from the outside world comes from
/// here: time, from a virtual clock that only moves when nothing is left to
/// run at the current instant, and chance, from a [Random] seeded with
/// [seed]. Code inside [run] sees its timers, `Future.delayed`, `Stream`
/// timeouts and `clock.now()` driven by the simulation, so two runs with
/// the same seed take the same steps and the whole run finishes in one
/// synchronous call.
///
/// Only one isolate takes part. Code that reaches for real I/O escapes the
/// simulation and makes a run stall or race.
final class Simulation {
  /// The seed of [random]. A failure reproduces from it.
  final int seed;

  /// The one source of chance for everything in the simulation.
  final Random random;

  /// What [now] reads at the start.
  final DateTime epoch;

  /// How far virtual time may advance before [run] gives up with a
  /// [SimulationOverrun], which catches a scenario that never ends.
  final Duration maxElapsed;

  /// How many [trace] entries are kept. Older ones are dropped.
  final int traceLimit;

  /// Whether `print` inside the simulation also reaches the real console.
  /// It is always recorded in [printed] and the [trace].
  final bool forwardPrints;

  Simulation({
    required this.seed,
    final DateTime? epoch,
    this.maxElapsed = const Duration(hours: 1),
    this.traceLimit = 20000,
    this.forwardPrints = false,
  }) : random = Random(seed),
       epoch = epoch ?? DateTime.utc(2026, 1, 1);

  var _elapsed = Duration.zero;

  /// Virtual time since the start.
  Duration get elapsed => _elapsed;

  /// The virtual wall clock: [epoch] plus [elapsed].
  DateTime get now => epoch.add(_elapsed);

  /// The `package:clock` clock installed inside [run].
  late final Clock clock = Clock(() => now);

  final _queue = SplayTreeSet<_SimTimer>(_SimTimer.compare);
  final _microtasks = Queue<void Function()>();
  var _sequence = 0;
  var _running = false;
  var _pendingTimers = 0;
  var _pendingEvents = 0;

  final _trace = ListQueue<TraceEntry>();
  var _droppedTraceEntries = 0;

  /// What happened, oldest first. Network traffic, prints, contract
  /// violations and whatever a scenario [record]s.
  Iterable<TraceEntry> get trace => _trace;

  /// Every line printed inside the simulation.
  final printed = <String>[];

  /// Timers created with `Timer`, `Future.delayed` and friends that have
  /// not fired or been cancelled. A clean shutdown leaves none.
  int get pendingTimers => _pendingTimers;

  /// Events scheduled with [schedule] that have not run.
  int get pendingEvents => _pendingEvents;

  /// Adds a line to the [trace] at the current instant.
  void record(final String category, final String message) {
    if (_trace.length >= traceLimit) {
      _trace.removeFirst();
      _droppedTraceEntries++;
    }
    _trace.add(TraceEntry(_elapsed, category, message));
  }

  /// The last [tail] lines of the trace, for a failure report.
  String dump({final int tail = 200}) {
    final buffer = StringBuffer()
      ..writeln('seed $seed, elapsed ${formatElapsed(_elapsed)}');
    final skipped = _droppedTraceEntries + max(0, _trace.length - tail);
    if (skipped > 0) buffer.writeln('... $skipped earlier entries');
    for (final entry in _trace.skip(max(0, _trace.length - tail))) {
      buffer.writeln(entry);
    }
    return buffer.toString();
  }

  /// Runs [callback] [delay] from now, in the calling zone. For the parts
  /// of the simulated world that act on their own, such as the network
  /// delivering bytes. Cancel through the returned [Timer].
  Timer schedule(final Duration delay, final void Function() callback) {
    final timer = _SimTimer(this, Zone.current, _due(delay), callback: callback)
      .._isEvent = true;
    _pendingEvents++;
    _queue.add(timer);
    return timer;
  }

  /// A delay in virtual time. Only meaningful inside [run].
  Future<void> sleep(final Duration delay) => Future<void>.delayed(delay);

  /// Runs [body] to completion in virtual time and returns its result.
  ///
  /// Microtasks run before any timer, timers run in order of their due
  /// time, and the clock jumps to each timer as it fires. Returns when the
  /// body's future completes. Throws [SimulationStalled] when it never can,
  /// and rethrows what the body threw.
  T run<T>(final FutureOr<T> Function() body) {
    if (_running) throw StateError('Simulation.run does not nest');
    _running = true;
    try {
      var done = false;
      T? value;
      Object? error;
      StackTrace? stackTrace;
      _zone.run(() {
        final result = body();
        if (result is Future<T>) {
          result.then(
            (final v) {
              value = v;
              done = true;
            },
            onError: (final Object e, final StackTrace s) {
              error = e;
              stackTrace = s;
              done = true;
            },
          );
        } else {
          value = result;
          done = true;
        }
      });
      while (!done) {
        if (!_step()) throw SimulationStalled(_elapsed);
      }
      _flushMicrotasks();
      if (error case final error?) {
        Error.throwWithStackTrace(error, stackTrace!);
      }
      return value as T;
    } finally {
      _running = false;
    }
  }

  /// Runs what is pending without waiting on anything in particular: every
  /// microtask, then every event and timer due within [within] of now.
  /// Virtual time ends at now plus [within] when something later remains.
  void settle(final Duration within) {
    final until = _elapsed + within;
    while (true) {
      _flushMicrotasks();
      final next = _queue.firstOrNull;
      if (next == null || next.due > until) break;
      _step();
    }
    if (until > _elapsed) _elapsed = until;
  }

  late final Zone _zone = withClock(
    clock,
    () => Zone.current.fork(
      specification: ZoneSpecification(
        createTimer:
            (
              final self,
              final parent,
              final zone,
              final duration,
              final callback,
            ) {
              final timer = _SimTimer(
                this,
                zone,
                _due(duration),
                callback: callback,
              );
              _pendingTimers++;
              _queue.add(timer);
              return timer;
            },
        createPeriodicTimer:
            (
              final self,
              final parent,
              final zone,
              final period,
              final callback,
            ) {
              final timer = _SimTimer(
                this,
                zone,
                _due(period),
                periodic: callback,
                period: period,
              );
              _pendingTimers++;
              _queue.add(timer);
              return timer;
            },
        scheduleMicrotask: (final self, final parent, final zone, final f) {
          _microtasks.add(() => zone.runGuarded(f));
        },
        print: (final self, final parent, final zone, final line) {
          printed.add(line);
          record('print', line);
          if (forwardPrints) parent.print(zone, line);
        },
      ),
    ),
  );

  Duration _due(final Duration delay) =>
      _elapsed + (delay.isNegative ? Duration.zero : delay);

  /// Runs the next microtask, or the next timer or event. False when
  /// there is none.
  bool _step() {
    if (_microtasks.isNotEmpty) {
      _microtasks.removeFirst()();
      return true;
    }
    final next = _queue.firstOrNull;
    if (next == null) return false;
    if (next.due > maxElapsed) throw SimulationOverrun(next.due, maxElapsed);
    _queue.remove(next);
    assert(next.due >= _elapsed, 'time runs forward');
    _elapsed = next.due;
    next._fire();
    return true;
  }

  void _flushMicrotasks() {
    while (_microtasks.isNotEmpty) {
      _microtasks.removeFirst()();
    }
  }

  void _remove(final _SimTimer timer) {
    if (_queue.remove(timer)) {
      if (timer._isEvent) {
        _pendingEvents--;
      } else {
        _pendingTimers--;
      }
    }
  }
}

final class _SimTimer implements Timer {
  final Simulation _sim;
  final Zone _zone;
  final void Function()? _callback;
  final void Function(Timer)? _periodic;
  final Duration? _period;
  Duration due;
  int sequence;
  var _active = true;
  var _tick = 0;
  var _isEvent = false;

  _SimTimer(
    this._sim,
    this._zone,
    this.due, {
    final void Function()? callback,
    final void Function(Timer)? periodic,
    final Duration? period,
  }) : _callback = callback,
       _periodic = periodic,
       _period = period,
       sequence = _sim._sequence++;

  static int compare(final _SimTimer a, final _SimTimer b) {
    final byDue = a.due.compareTo(b.due);
    return byDue != 0 ? byDue : a.sequence.compareTo(b.sequence);
  }

  @override
  void cancel() {
    if (!_active) return;
    _active = false;
    _sim._remove(this);
  }

  @override
  bool get isActive => _active;

  @override
  int get tick => _tick;

  /// Called by the simulation after taking this timer off the queue.
  void _fire() {
    if (!_active) return;
    _tick++;
    if (_periodic case final periodic?) {
      // Back on the queue before the callback, so a callback that cancels
      // the timer finds it there, and one that reads the time sees it
      // advanced, as a real periodic timer behaves. A zero period takes a
      // microsecond, so time moves and maxElapsed holds.
      due += _period! > Duration.zero
          ? _period
          : const Duration(microseconds: 1);
      sequence = _sim._sequence++;
      _sim._queue.add(this);
      _zone.runUnaryGuarded(periodic, this);
      return;
    }
    _active = false;
    if (_isEvent) {
      _sim._pendingEvents--;
    } else {
      _sim._pendingTimers--;
    }
    _zone.runGuarded(_callback!);
  }
}
