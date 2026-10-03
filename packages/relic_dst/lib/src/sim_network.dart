import 'dart:async';
import 'dart:collection';
import 'dart:math';
import 'dart:typed_data';

import 'package:stream_channel/stream_channel.dart';

import 'simulation.dart';

/// How a [SimNetwork] treats the bytes it carries. Every choice it makes
/// comes from the simulation's seeded [Random].
final class NetworkOptions {
  /// The least and most time a piece of data spends on the wire.
  final Duration minLatency;
  final Duration maxLatency;

  /// The chance that a write is cut into more than one piece.
  final double fragmentation;

  /// The most bytes delivered in one piece.
  final int maxSegment;

  /// How many bytes an endpoint holds for a reader that has not taken
  /// them. Past that the sender stalls until the reader catches up, the
  /// way TCP flow control stalls a writer whose peer stopped reading.
  final int receiveWindow;

  /// The chance, per delivered piece, that the network resets the
  /// connection instead.
  final double resetProbability;

  const NetworkOptions({
    this.minLatency = const Duration(microseconds: 50),
    this.maxLatency = const Duration(milliseconds: 2),
    this.fragmentation = 0.3,
    this.maxSegment = 1460,
    this.receiveWindow = 64 << 10,
    this.resetProbability = 0,
  });

  /// Bytes arrive whole and at once, for a scenario about something else.
  static const quiet = NetworkOptions(
    minLatency: Duration.zero,
    maxLatency: Duration.zero,
    fragmentation: 0,
    maxSegment: 1 << 30,
  );
}

/// Nothing listens on the port, or the listener closed.
final class SimConnectionRefused implements Exception {
  final int port;

  const SimConnectionRefused(this.port);

  @override
  String toString() => 'Connection refused on port $port';
}

/// The peer, or the network, reset the connection.
final class SimConnectionReset implements Exception {
  const SimConnectionReset();

  @override
  String toString() => 'Connection reset by peer';
}

/// A loopback network inside a [Simulation]: listeners on ports, and
/// connections between them and clients, with latency, fragmentation,
/// flow control, half-close and reset.
final class SimNetwork {
  final Simulation sim;
  final NetworkOptions options;
  final _listeners = <int, SimListener>{};
  var _nextListenerPort = 8000;
  var _nextClientPort = 40000;
  var _connections = 0;

  /// The address every endpoint has.
  static const address = '127.0.0.1';

  SimNetwork(this.sim, {this.options = const NetworkOptions()});

  /// Binds [port], or the next free one for 0.
  SimListener listen({int port = 0}) {
    if (port == 0) {
      while (_listeners.containsKey(_nextListenerPort)) {
        _nextListenerPort++;
      }
      port = _nextListenerPort++;
    }
    if (_listeners.containsKey(port)) {
      throw StateError('Port $port is already bound');
    }
    return _listeners[port] = SimListener._(this, port);
  }

  /// Opens a connection to [port]. Fails with [SimConnectionRefused] when
  /// nothing listens there by the time the connection attempt arrives.
  Future<SimSocket> connect(final int port) {
    final completer = Completer<SimSocket>();
    final clientPort = _nextClientPort++;
    sim.schedule(latency(), () {
      final listener = _listeners[port];
      if (listener == null || listener.isClosed) {
        sim.record('net', 'connect :$clientPort -> :$port refused');
        completer.completeError(SimConnectionRefused(port));
        return;
      }
      final link = _Link(this, ++_connections);
      final client = SimSocket._(link, '#${link.id}c', clientPort, port);
      final server = SimSocket._(link, '#${link.id}s', port, clientPort);
      link._a = client;
      link._b = server;
      sim.record('net', '#${link.id} connect :$clientPort -> :$port');
      listener._accept(server);
      completer.complete(client);
    });
    return completer.future;
  }

  /// One wire delay, drawn from the options.
  Duration latency() {
    final span =
        options.maxLatency.inMicroseconds - options.minLatency.inMicroseconds;
    if (span <= 0) return options.minLatency;
    return options.minLatency +
        Duration(microseconds: sim.random.nextInt(span + 1));
  }
}

/// A bound port. Connections wait in the backlog until [listen] is called.
final class SimListener {
  final SimNetwork _network;
  final int port;
  void Function(SimSocket)? _onConnection;
  final _backlog = Queue<SimSocket>();
  var _closed = false;

  SimListener._(this._network, this.port);

  /// The network this port is bound on.
  SimNetwork get network => _network;

  bool get isClosed => _closed;

  /// Hands every connection, queued or to come, to [onConnection].
  void listen(final void Function(SimSocket) onConnection) {
    _onConnection = onConnection;
    while (_backlog.isNotEmpty) {
      onConnection(_backlog.removeFirst());
    }
  }

  /// Stops accepting. Connections in the backlog are reset, and later
  /// attempts are refused.
  void close() {
    if (_closed) return;
    _closed = true;
    _network._listeners.remove(port);
    for (final socket in _backlog) {
      socket.destroy();
    }
    _backlog.clear();
  }

  void _accept(final SimSocket socket) {
    final onConnection = _onConnection;
    if (onConnection != null) {
      onConnection(socket);
    } else {
      _backlog.add(socket);
    }
  }
}

final class _Link {
  final SimNetwork network;
  final int id;
  late SimSocket _a;
  late SimSocket _b;

  _Link(this.network, this.id);

  SimSocket peerOf(final SimSocket socket) => identical(socket, _a) ? _b : _a;
}

/// One end of a simulated connection, as a byte channel.
///
/// Writes go out in pieces after a latency, in order. Closing the sink
/// sends a FIN after the last piece and completes once the peer has it.
/// A peer that holds more than the receive window stalls the sender,
/// and the close never completes, as a real socket to a peer that stopped
/// reading behaves. [destroy] resets the connection: the peer's stream
/// fails with [SimConnectionReset].
final class SimSocket with StreamChannelMixin<Uint8List> {
  final _Link _link;
  final String _label;
  final int localPort;
  final int remotePort;

  late final StreamController<Uint8List> _rx = StreamController<Uint8List>(
    onListen: _deliver,
    onResume: _deliver,
  );
  final _rxQueue = Queue<Uint8List>();
  var _rxBytes = 0;
  var _finReceived = false;
  var _rxClosed = false;

  final _tx = Queue<Uint8List>();
  var _txBytes = 0;
  var _inFlight = 0;
  var _lastDue = Duration.zero;
  var _sinkClosed = false;
  var _finSent = false;
  var _stalled = false;
  var _reset = false;
  final _flushed = Completer<void>();

  /// Called each time bytes written here reached the peer, for a writer
  /// that paces itself by [pendingBytes].
  void Function()? onDrain;

  @override
  late final StreamSink<Uint8List> sink = _SimSink(this);

  SimSocket._(this._link, this._label, this.localPort, this.remotePort);

  @override
  Stream<Uint8List> get stream => _rx.stream;

  Simulation get _sim => _link.network.sim;
  NetworkOptions get _options => _link.network.options;
  SimSocket get _peer => _link.peerOf(this);

  /// Whether this end can still write: it has not closed and the
  /// connection was not reset.
  bool get isOpen => !_sinkClosed && !_reset;

  /// Whether the connection was reset, by either side or the network.
  bool get isReset => _reset;

  /// Completes when this end is done writing: the FIN reached the peer,
  /// or the connection was reset. Never fails.
  Future<void> get done => _flushed.future;

  /// Bytes received and not yet taken by the reader.
  int get unreadBytes => _rxBytes;

  /// Bytes written and not yet delivered to the peer.
  int get pendingBytes => _inFlight + _txBytes;

  /// Resets the connection. The peer learns after a latency.
  void destroy() {
    if (_reset) return;
    _sim.record('net', '$_label destroy');
    final peer = _peer;
    final delay = _nextDue() - _sim.elapsed;
    _resetLocally();
    if (!peer._reset) _sim.schedule(delay, peer._receiveReset);
  }

  void _add(final Uint8List bytes) {
    if (_sinkClosed) throw StateError('The socket is closed');
    if (_reset || bytes.isEmpty) return;
    _tx.add(bytes);
    _txBytes += bytes.length;
    _pump();
  }

  Future<void> _close() {
    if (!_sinkClosed) {
      _sinkClosed = true;
      _sim.record('net', '$_label close');
      _pump();
    }
    return _flushed.future;
  }

  /// Moves what the peer's window allows from the queue onto the wire.
  ///
  /// A piece goes out only when the window has room for a whole segment,
  /// or for all that is left. Sending into whatever room a delivery just
  /// freed would shrink the pieces towards one byte each, which is the
  /// silly window syndrome TCP avoids the same way.
  void _pump() {
    if (_reset) return;
    final peer = _peer;
    while (_tx.isNotEmpty) {
      final available = _options.receiveWindow - peer._rxBytes - _inFlight;
      final wanted = min(
        _txBytes,
        min(_options.maxSegment, _options.receiveWindow),
      );
      if (available < wanted) {
        if (!_stalled) {
          _stalled = true;
          _sim.record('net', '$_label stalled, the peer stopped reading');
        }
        return;
      }
      _stalled = false;
      final chunk = _tx.removeFirst();
      var size = min(chunk.length, wanted);
      if (size > 1 && _sim.random.nextDouble() < _options.fragmentation) {
        size = 1 + _sim.random.nextInt(size);
      }
      if (size < chunk.length) {
        _tx.addFirst(Uint8List.sublistView(chunk, size));
      }
      final piece = Uint8List.sublistView(chunk, 0, size);
      _txBytes -= size;
      _inFlight += size;
      _sim.schedule(
        _nextDue() - _sim.elapsed,
        () => peer._receive(piece, this),
      );
    }
    if (_sinkClosed && !_finSent) {
      _finSent = true;
      _sim.schedule(_nextDue() - _sim.elapsed, () => peer._receiveFin(this));
    }
  }

  /// When the next piece lands: after a latency, and never before the
  /// piece ahead of it.
  Duration _nextDue() {
    final due = _sim.elapsed + _link.network.latency();
    return _lastDue = due > _lastDue ? due : _lastDue;
  }

  void _receive(final Uint8List piece, final SimSocket from) {
    from._inFlight -= piece.length;
    from.onDrain?.call();
    if (_reset) return;
    if (_options.resetProbability > 0 &&
        _sim.random.nextDouble() < _options.resetProbability) {
      _sim.record('net', '#${_link.id} reset by the network');
      _resetLocally(error: const SimConnectionReset());
      from._resetLocally(error: const SimConnectionReset());
      return;
    }
    _sim.record('net', '${from._label} -> $_label ${piece.length} bytes');
    _rxQueue.add(piece);
    _rxBytes += piece.length;
    _deliver();
  }

  void _receiveFin(final SimSocket from) {
    if (!from._flushed.isCompleted) from._flushed.complete();
    if (_reset) return;
    _sim.record('net', '${from._label} -> $_label FIN');
    _finReceived = true;
    _deliver();
  }

  void _receiveReset() {
    if (_reset) return;
    _sim.record('net', '$_label reset by peer');
    _resetLocally(error: const SimConnectionReset());
  }

  /// Hands queued bytes to a reader that takes them, ends the stream once
  /// the peer's FIN is behind them, and lets the peer write into the
  /// window that freed up.
  void _deliver() {
    while (_rxQueue.isNotEmpty && _rx.hasListener && !_rx.isPaused) {
      final piece = _rxQueue.removeFirst();
      _rxBytes -= piece.length;
      _rx.add(piece);
    }
    if (_rxQueue.isEmpty && _finReceived && !_rxClosed) {
      _rxClosed = true;
      unawaited(_rx.close());
    }
    if (!_reset) _peer._pump();
  }

  void _resetLocally({final Object? error}) {
    _reset = true;
    _tx.clear();
    _txBytes = 0;
    _rxQueue.clear();
    _rxBytes = 0;
    if (!_rxClosed) {
      _rxClosed = true;
      if (error != null) _rx.addError(error);
      unawaited(_rx.close());
    }
    if (!_flushed.isCompleted) _flushed.complete();
  }

  @override
  String toString() => 'SimSocket($_label :$localPort -> :$remotePort)';
}

final class _SimSink implements StreamSink<Uint8List> {
  final SimSocket _socket;

  _SimSink(this._socket);

  @override
  void add(final Uint8List data) => _socket._add(data);

  @override
  void addError(final Object error, [final StackTrace? stackTrace]) {
    // A byte channel has no way to carry an error to the peer. Nothing
    // goes out, as nothing would on a socket.
    _socket._sim.record('net', '${_socket._label} addError ignored: $error');
  }

  @override
  Future<void> addStream(final Stream<Uint8List> stream) => stream.forEach(add);

  @override
  Future<void> close() => _socket._close();

  @override
  Future<void> get done => _socket.done;
}
