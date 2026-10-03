import 'dart:async';
import 'dart:typed_data';

import 'package:relic_core/relic_core.dart';
import 'package:stream_channel/stream_channel.dart';

import 'simulation.dart';

/// A breach of the contract between an [Adapter] and the core, seen by a
/// [ContractAdapter].
final class ContractViolation {
  final Duration at;
  final String rule;
  final String detail;

  ContractViolation(this.at, this.rule, this.detail);

  @override
  String toString() => '${formatElapsed(at)} $rule: $detail';
}

/// Watches every call across the adapter boundary against what [Adapter]
/// and [AdapterExchange] promise, from both sides.
///
/// Violations are recorded in [violations] and the simulation's trace,
/// and nothing is thrown, so a scenario runs to its end and reports them
/// all. Wrap the adapter under test and hand the wrapper to the server.
final class ContractAdapter implements Adapter {
  final Adapter inner;
  final Simulation sim;
  final violations = <ContractViolation>[];
  final exchanges = <ContractExchange>[];
  var _started = false;
  var _closeCompleted = false;

  ContractAdapter(this.inner, this.sim);

  void violate(final String rule, final String detail) {
    violations.add(ContractViolation(sim.elapsed, rule, detail));
    sim.record('contract', '$rule: $detail');
  }

  @override
  AdapterCapabilities get capabilities => inner.capabilities;

  @override
  List<Listener> get listeners => inner.listeners;

  @override
  void start(final ExchangeSink sink) {
    if (_started) violate('start is called once', 'start was called again');
    _started = true;
    inner.start((final exchange) {
      if (_closeCompleted) {
        violate(
          'no exchange reaches the sink after close completed',
          'an exchange arrived',
        );
      }
      final wrapped = ContractExchange._(this, exchange);
      exchanges.add(wrapped);
      try {
        final pending = sink(wrapped);
        if (pending is Future<void>) {
          return pending.catchError((final Object error) {
            violate('the sink never fails', 'its future failed with $error');
          });
        }
        return pending;
      } catch (error) {
        violate('the sink never fails', 'it threw $error');
        return null;
      }
    });
  }

  @override
  Future<void> close({final bool force = false}) async {
    await inner.close(force: force);
    _closeCompleted = true;
    // The adapter ended its exchanges as it closed. Their done futures
    // reach this wrapper a microtask later.
    await Future<void>.microtask(() {});
    for (final exchange in exchanges) {
      if (exchange._end == null) {
        violate(
          'every exchange has ended when close completes',
          '${exchange._describe()} is still open',
        );
      }
    }
    final info = inner.connectionsInfo;
    if (info.active != 0 || info.closing != 0 || info.idle != 0) {
      violate('no connections remain after close', '$info');
    }
  }

  @override
  ConnectionsInfo get connectionsInfo {
    final info = inner.connectionsInfo;
    if (info.active < 0 || info.closing < 0 || info.idle < 0) {
      violate('connection counts are not negative', '$info');
    }
    return info;
  }
}

/// One exchange under the [ContractAdapter]'s watch.
final class ContractExchange implements AdapterExchange {
  final ContractAdapter _adapter;
  final AdapterExchange inner;
  String? _terminal;
  var _respondFailed = false;
  ExchangeEnd? _end;
  var _ended = Duration.zero;
  final Duration _started;

  ContractExchange._(this._adapter, this.inner)
    : _started = _adapter.sim.elapsed {
    unawaited(
      inner.done.then((final end) {
        _end = end;
        _ended = _adapter.sim.elapsed;
        _checkEnd(end);
      }),
    );
    unawaited(
      inner.cancelled.then((_) {
        if (_end != null && _end != ExchangeEnd.cancelledByPeer) {
          _violate(
            'cancelled completes only before the end, or with it',
            'it completed after done gave $_end',
          );
        }
      }),
    );
  }

  void _violate(final String rule, final String detail) =>
      _adapter.violate(rule, '${_describe()}: $detail');

  String _describe() =>
      'exchange ${_adapter.exchanges.indexOf(this)} (${_terminal ?? 'untouched'}'
      '${_end == null ? '' : ', ended $_end'})';

  void _checkEnd(final ExchangeEnd end) {
    final allowed = switch (_terminal) {
      null => const {ExchangeEnd.aborted, ExchangeEnd.cancelledByPeer},
      'respond' => const {
        ExchangeEnd.completed,
        ExchangeEnd.aborted,
        ExchangeEnd.cancelledByPeer,
      },
      'hijack' => const {ExchangeEnd.hijacked, ExchangeEnd.cancelledByPeer},
      'upgradeWebSocket' => const {
        ExchangeEnd.upgraded,
        ExchangeEnd.cancelledByPeer,
      },
      _ => const {ExchangeEnd.aborted, ExchangeEnd.cancelledByPeer},
    };
    if (!allowed.contains(end)) {
      _violate('done agrees with the call made', 'it gave $end');
    }
  }

  /// The core's side: one of respond, hijack, upgradeWebSocket and abort,
  /// once. After a respond that failed the core may try an error response
  /// or abort, and the adapter owes it a no-op when the exchange is over.
  /// A hijack the adapter refuses with a [StateError] leaves the exchange
  /// with the core and does not count.
  void _terminalCall(final String name) {
    final previous = _terminal;
    final retry = _respondFailed && (name == 'respond' || name == 'abort');
    if (previous != null && !retry) {
      _violate(
        'the core calls one of respond, hijack, upgradeWebSocket and abort, '
            'once',
        '$name after $previous',
      );
      return;
    }
    _terminal ??= name;
  }

  @override
  HttpProtocol get protocol => inner.protocol;

  @override
  Request toRequest(final RequestFactory create) => inner.toRequest(create);

  @override
  FutureOr<void> respond(final Response response) {
    _terminalCall('respond');
    final FutureOr<void> pending;
    try {
      pending = inner.respond(response);
    } catch (error) {
      if (_end == ExchangeEnd.aborted || _end == ExchangeEnd.cancelledByPeer) {
        _violate('respond after abort or cancel is a no-op', 'it threw $error');
      }
      _respondFailed = true;
      rethrow;
    }
    if (pending is Future<void>) {
      return pending.catchError((final Object error) {
        _respondFailed = true;
        throw error;
      });
    }
    return pending;
  }

  @override
  FutureOr<StreamChannel<Uint8List>> hijack() {
    final previous = _terminal;
    _terminalCall('hijack');
    if (!_adapter.capabilities.hijack) {
      _violate('hijack is only called with the capability', 'it was called');
    }
    try {
      return inner.hijack();
    } on StateError {
      _terminal = previous;
      rethrow;
    }
  }

  @override
  FutureOr<RelicWebSocket> upgradeWebSocket(final String acceptKey) {
    _terminalCall('upgradeWebSocket');
    if (!_adapter.capabilities.webSocket) {
      _violate(
        'upgradeWebSocket is only called with the capability',
        'it was called',
      );
    }
    return inner.upgradeWebSocket(acceptKey);
  }

  @override
  void abort() {
    _terminalCall('abort');
    try {
      inner.abort();
    } catch (error) {
      _violate('abort never throws', 'it threw $error');
    }
  }

  @override
  Future<void> get cancelled => inner.cancelled;

  @override
  Future<ExchangeEnd> get done => inner.done;

  /// How the exchange ended, once it has.
  ExchangeEnd? get end => _end;

  /// When it ended, in simulated time.
  Duration get endedAt => _ended;

  Duration get startedAt => _started;
}
