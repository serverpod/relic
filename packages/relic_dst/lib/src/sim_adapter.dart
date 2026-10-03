import 'dart:async';
import 'dart:math';
import 'dart:typed_data';

import 'package:relic_core/relic_core.dart';
import 'package:stream_channel/stream_channel.dart';

import 'http1.dart';
import 'sim_network.dart';
import 'simulation.dart';

/// An HTTP/1.1 [Adapter] over a [SimNetwork], in Dart, with no socket
/// anywhere.
///
/// It does what the real adapters do between the bytes and the core:
/// parses heads, hands bodies over inline or as a stream, writes what
/// [ResponseFraming] decides, keeps connections alive, serves pipelined
/// requests in order, times out slow peers, detaches a hijacked
/// connection, and drains on a graceful close. Every timeout is a
/// simulated timer, so a scenario about a 60 second idle timeout runs in
/// no time at all and lands on the exact instant.
///
/// It advertises hijack and no WebSocket support, so the core frames
/// WebSockets over the hijacked channel, which puts [FramedWebSocket]
/// under the simulation too.
final class SimAdapter implements Adapter {
  final SimListener _listener;
  final Simulation _sim;

  /// How long a connection may wait for the first byte of a request.
  final Duration idleTimeout;

  /// How long the rest of a head may take after its first byte.
  final Duration headerTimeout;

  /// How long a body may go without a byte arriving.
  final Duration bodyTimeout;

  /// How long a graceful close waits for in-flight exchanges, and then for
  /// hijacked connections, before dropping them.
  final Duration drainTimeout;

  /// A head over this many bytes is answered 431.
  final int maxHeadSize;

  /// A body up to this size is read before the request is handed over.
  /// A larger or chunked one streams to the handler.
  final int maxInlineBody;

  final _connections = <_Connection>{};
  final _hijacked = <_Connection>{};
  ExchangeSink? _sink;
  var _closing = false;
  var _closed = false;
  Future<void>? _closeFuture;
  Completer<void>? _drained;
  Completer<void>? _released;
  var _inFlight = 0;

  SimAdapter(
    this._listener, {
    this.idleTimeout = const Duration(seconds: 60),
    this.headerTimeout = const Duration(seconds: 10),
    this.bodyTimeout = const Duration(seconds: 30),
    this.drainTimeout = const Duration(seconds: 5),
    this.maxHeadSize = 16 << 10,
    this.maxInlineBody = 1 << 20,
  }) : _sim = _listener.network.sim;

  /// Binds [port] on [network], or a free port for 0.
  factory SimAdapter.bind(
    final SimNetwork network, {
    final int port = 0,
    final Duration idleTimeout = const Duration(seconds: 60),
    final Duration headerTimeout = const Duration(seconds: 10),
    final Duration bodyTimeout = const Duration(seconds: 30),
    final Duration drainTimeout = const Duration(seconds: 5),
    final int maxHeadSize = 16 << 10,
    final int maxInlineBody = 1 << 20,
  }) => SimAdapter(
    network.listen(port: port),
    idleTimeout: idleTimeout,
    headerTimeout: headerTimeout,
    bodyTimeout: bodyTimeout,
    drainTimeout: drainTimeout,
    maxHeadSize: maxHeadSize,
    maxInlineBody: maxInlineBody,
  );

  int get port => _listener.port;

  /// The authority of a request without a Host, which HTTP/1.0 allows.
  String get authority => '${SimNetwork.address}:$port';

  @override
  AdapterCapabilities get capabilities =>
      const AdapterCapabilities(hijack: true);

  @override
  List<Listener> get listeners => [
    Listener(Transport.tcp, SimNetwork.address, port, const {
      HttpProtocol.http10,
      HttpProtocol.http11,
    }),
  ];

  @override
  void start(final ExchangeSink sink) {
    if (_sink != null) throw StateError('start was already called');
    _sink = sink;
    _listener.listen(_accept);
  }

  void _accept(final SimSocket socket) {
    if (_closing) {
      socket.destroy();
      return;
    }
    final connection = _Connection(this, socket);
    _connections.add(connection);
    _sim.record('adapter', '${connection.label} accepted');
    connection._start();
  }

  @override
  Future<void> close({final bool force = false}) =>
      _closeFuture ??= _close(force);

  Future<void> _close(final bool force) async {
    _closing = true;
    _listener.close();
    if (!force) {
      for (final connection in _connections.toList()) {
        if (connection.isIdle) connection._finish();
      }
      if (_inFlight > 0) {
        final drained = _drained = Completer<void>();
        await drained.future.timeout(drainTimeout, onTimeout: () {});
      }
      if (_hijacked.isNotEmpty) {
        final released = _released = Completer<void>();
        for (final connection in _hijacked.toList()) {
          connection._closeRaw();
        }
        await released.future.timeout(drainTimeout, onTimeout: () {});
      }
    }
    for (final connection in [..._connections, ..._hijacked]) {
      connection._destroy(end: ExchangeEnd.aborted);
    }
    _closed = true;
    _sim.record('adapter', 'closed${force ? ' by force' : ''}');
  }

  @override
  ConnectionsInfo get connectionsInfo {
    if (_closed) return (active: 0, closing: 0, idle: 0);
    var active = _hijacked.length;
    var idle = 0;
    var closing = 0;
    for (final connection in _connections) {
      switch (connection._state) {
        case _State.idle:
          idle++;
        case _State.head:
        case _State.body:
        case _State.active:
          active++;
        case _State.closing:
          closing++;
        case _State.hijacked:
        case _State.closed:
          break;
      }
    }
    return (active: active, closing: closing, idle: idle);
  }

  void _exchangeStarted() => _inFlight++;

  void _exchangeEnded() {
    _inFlight--;
    if (_inFlight == 0) _settle(_drained);
  }

  void _tookOver(final _Connection connection) {
    _connections.remove(connection);
    _hijacked.add(connection);
  }

  void _gone(final _Connection connection) {
    _connections.remove(connection);
    _hijacked.remove(connection);
    if (_hijacked.isEmpty) _settle(_released);
  }

  static void _settle(final Completer<void>? waiter) {
    if (waiter != null && !waiter.isCompleted) waiter.complete();
  }
}

enum _State {
  /// Waiting for the first byte of a request.
  idle,

  /// Bytes of a head have arrived and it is not complete.
  head,

  /// The head is parsed and an inline body is still arriving.
  body,

  /// An exchange is with the core.
  active,

  /// The FIN is sent, or the peer's was the end of it.
  closing,
  hijacked,
  closed,
}

final class _Connection {
  final SimAdapter _adapter;
  final SimSocket _socket;
  final String label;
  late final StreamSubscription<Uint8List> _subscription;
  var _buffer = Uint8List(4096);
  var _length = 0;
  var _state = _State.idle;
  Timer? _timer;
  _SimExchange? _exchange;
  RequestHead? _head;

  /// The streamed request body, while there is one.
  StreamController<Uint8List>? _body;
  ChunkedDecoder? _chunked;
  var _bodyRemaining = 0;
  var _bodyDone = true;

  /// Whether another request may follow on this connection.
  var _reusable = true;
  var _peerClosed = false;
  StreamController<Uint8List>? _raw;

  _Connection(this._adapter, this._socket)
    : label = 'conn :${_socket.remotePort}';

  Simulation get _sim => _adapter._sim;

  bool get isIdle => _state == _State.idle;

  void _start() {
    _subscription = _socket.stream.listen(
      _onData,
      onError: _onError,
      onDone: _onDone,
    );
    _arm(_adapter.idleTimeout, _onIdleTimeout);
  }

  void _arm(final Duration timeout, final void Function() onTimeout) {
    _timer?.cancel();
    _timer = timeout == Duration.zero ? null : Timer(timeout, onTimeout);
  }

  void _disarm() {
    _timer?.cancel();
    _timer = null;
  }

  void _onData(final Uint8List data) {
    switch (_state) {
      case _State.hijacked:
        _raw!.add(data);
        return;
      case _State.closing:
      case _State.closed:
        return;
      case _State.idle:
        _state = _State.head;
        _arm(_adapter.headerTimeout, _onHeaderTimeout);
      case _State.body:
        _arm(_adapter.bodyTimeout, _onBodyTimeout);
      case _State.active:
        if (!_bodyDone) _arm(_adapter.bodyTimeout, _onBodyTimeout);
      case _State.head:
        break;
    }
    _append(data);
    _process();
  }

  /// Parses and dispatches what the buffer holds, as far as it goes.
  void _process() {
    while (true) {
      switch (_state) {
        case _State.head:
          final RequestHead head;
          try {
            final parsed = parseRequestHead(
              _buffer,
              _length,
              maxHeadSize: _adapter.maxHeadSize,
            );
            if (parsed == null) return;
            head = parsed;
          } on HttpParseException catch (e) {
            _reject(e.status, e.message);
            return;
          }
          _consume(head.bytes.length);
          _head = head;
          _disarm();
          final contentLength = head.contentLength ?? 0;
          if (head.chunked) {
            _chunked = ChunkedDecoder();
            _bodyDone = false;
            _arm(_adapter.bodyTimeout, _onBodyTimeout);
            _dispatch(head, stream: _bodyStream());
          } else if (contentLength > 0 &&
              contentLength <= _adapter.maxInlineBody) {
            _state = _State.body;
            _bodyRemaining = contentLength;
            _arm(_adapter.bodyTimeout, _onBodyTimeout);
          } else if (contentLength > 0) {
            _bodyRemaining = contentLength;
            _bodyDone = false;
            _arm(_adapter.bodyTimeout, _onBodyTimeout);
            _dispatch(
              head,
              stream: _bodyStream(),
              contentLength: contentLength,
            );
          } else {
            _dispatch(head);
          }
        case _State.body:
          if (_length < _bodyRemaining) return;
          final bytes = _take(_bodyRemaining);
          _bodyRemaining = 0;
          _disarm();
          _dispatch(_head!, bytes: bytes);
        case _State.active:
          if (_bodyDone || _length == 0) return;
          _feedBody();
          return;
        case _State.idle:
        case _State.closing:
        case _State.hijacked:
        case _State.closed:
          return;
      }
    }
  }

  Stream<Uint8List> _bodyStream() {
    final controller = StreamController<Uint8List>(
      onPause: () {
        _subscription.pause();
        // A paused reader is not a slow peer.
        _disarm();
      },
      onResume: () {
        _subscription.resume();
        if (!_bodyDone) {
          _arm(_adapter.bodyTimeout, _onBodyTimeout);
          _process();
        }
      },
      onCancel: () {
        if (!_bodyDone) _abandonBody();
      },
    );
    _body = controller;
    return controller.stream;
  }

  void _feedBody() {
    final controller = _body!;
    if (_chunked case final chunked?) {
      final int consumed;
      try {
        consumed = chunked.feed(_buffer, 0, _length, (final piece) {
          controller.add(Uint8List.fromList(piece));
        });
      } on FormatException catch (e) {
        _failBody(e);
        return;
      }
      _consume(consumed);
      if (chunked.isDone) _bodyComplete();
      return;
    }
    final n = min(_length, _bodyRemaining);
    controller.add(_take(n));
    _bodyRemaining -= n;
    if (_bodyRemaining == 0) _bodyComplete();
  }

  void _bodyComplete() {
    _bodyDone = true;
    _disarm();
    final body = _body;
    _body = null;
    _chunked = null;
    if (body != null) unawaited(body.close());
    if (_exchange == null) _afterExchange();
  }

  /// The body cannot be finished. The handler hears why, and the
  /// connection closes after the response, since the rest of the body is
  /// not coming or cannot be found.
  void _failBody(final Object error) {
    _sim.record('adapter', '$label body failed: $error');
    final body = _body;
    _bodyDone = true;
    _reusable = false;
    _body = null;
    _chunked = null;
    _disarm();
    if (body != null && !body.isClosed) {
      body.addError(error);
      unawaited(body.close());
    }
    if (_exchange == null) _afterExchange();
  }

  /// The handler is done with the body before it all arrived. What is
  /// left stays on the wire, and the connection closes after the response.
  void _abandonBody() {
    _bodyDone = true;
    _reusable = false;
    final body = _body;
    _body = null;
    _chunked = null;
    _disarm();
    if (body != null && !body.isClosed) unawaited(body.close());
    _subscription.resume();
  }

  void _dispatch(
    final RequestHead head, {
    final Uint8List? bytes,
    final Stream<Uint8List>? stream,
    final int? contentLength,
  }) {
    _state = _State.active;
    if (!head.keepAlive) _reusable = false;
    final exchange = _exchange = _SimExchange(
      this,
      head,
      bytes: bytes,
      stream: stream,
      contentLength: contentLength,
    );
    _adapter._exchangeStarted();
    _sim.record(
      'adapter',
      '$label ${head.method.value} ${String.fromCharCodes(head.target)}',
    );
    final pending = _adapter._sink!(exchange);
    if (pending is Future<void>) unawaited(pending);
  }

  /// The exchange is over. The next request is served, or the connection
  /// closes when it cannot be.
  void _exchangeFinished() {
    _exchange = null;
    _adapter._exchangeEnded();
    if (!_bodyDone) {
      _abandonBody();
    }
    _afterExchange();
  }

  void _afterExchange() {
    if (_exchange != null || !_bodyDone) return;
    if (_state == _State.closed ||
        _state == _State.closing ||
        _state == _State.hijacked) {
      return;
    }
    if (!_reusable || _peerClosed || _adapter._closing) {
      _finish();
      return;
    }
    _state = _State.idle;
    _arm(_adapter.idleTimeout, _onIdleTimeout);
    if (_length > 0) {
      _state = _State.head;
      _arm(_adapter.headerTimeout, _onHeaderTimeout);
      scheduleMicrotask(_process);
    }
  }

  void _write(final Uint8List bytes) {
    if (!_socket.isOpen || bytes.isEmpty) return;
    _socket.sink.add(bytes);
  }

  /// Answers a request the adapter will not hand over, and closes.
  void _reject(final int status, final String message) {
    _sim.record('adapter', '$label rejected $status: $message');
    final response = Response(status, body: Body.fromString(message));
    final framing = ResponseFraming.of(
      response,
      head: false,
      protocol: HttpProtocol.http11,
      keepAlive: false,
    );
    _write(encodeResponseHead(response, framing));
    _write(response.body.bytes!);
    _finish();
  }

  /// Sends the FIN. The connection is gone once it is delivered.
  void _finish() {
    if (_state == _State.closing || _state == _State.closed) return;
    _state = _State.closing;
    _disarm();
    unawaited(_socket.sink.close().then((_) => _gone()));
  }

  void _gone() {
    if (_state == _State.closed) return;
    _state = _State.closed;
    _disarm();
    unawaited(_subscription.cancel());
    _adapter._gone(this);
  }

  /// Drops the connection. An exchange still with the core ends with
  /// [end].
  void _destroy({required final ExchangeEnd end}) {
    final exchange = _exchange;
    _exchange = null;
    if (exchange != null) {
      _adapter._exchangeEnded();
      exchange._ended(end);
    }
    if (!_bodyDone) _failBody(const SimConnectionReset());
    if (_raw case final raw?) {
      if (!raw.isClosed) unawaited(raw.close());
    }
    _socket.destroy();
    _gone();
  }

  void _onIdleTimeout() {
    _sim.record('adapter', '$label idle timeout');
    _finish();
  }

  void _onHeaderTimeout() =>
      _reject(408, 'The request head did not arrive in time');

  void _onBodyTimeout() {
    if (_state == _State.body) {
      _reject(408, 'The request body did not arrive in time');
      return;
    }
    _failBody(TimeoutException('The request body stalled'));
  }

  /// The peer sent its FIN. A request in progress ends, a response can
  /// still go out, and nothing follows on this connection.
  void _onDone() {
    _peerClosed = true;
    _reusable = false;
    switch (_state) {
      case _State.idle:
        _finish();
      case _State.head:
        if (_length == 0) {
          _finish();
        } else {
          _reject(400, 'The request ended inside its head');
        }
      case _State.body:
        _reject(400, 'The request body ended early');
      case _State.active:
        if (!_bodyDone) _failBody(const SimConnectionReset());
      case _State.hijacked:
        final raw = _raw!;
        if (!raw.isClosed) unawaited(raw.close());
      case _State.closing:
      case _State.closed:
        break;
    }
  }

  /// The peer reset the connection.
  void _onError(final Object error) {
    _sim.record('adapter', '$label reset by peer');
    if (_raw case final raw?) {
      if (!raw.isClosed) raw.addError(error);
    }
    _destroy(end: ExchangeEnd.cancelledByPeer);
  }

  /// Hands the connection to a handler as a raw channel. Bytes already
  /// read past the head come first.
  StreamChannel<Uint8List> _detach() {
    _disarm();
    _state = _State.hijacked;
    _exchange = null;
    _adapter._exchangeEnded();
    _adapter._tookOver(this);
    final raw = _raw = StreamController<Uint8List>(
      onPause: _subscription.pause,
      onResume: _subscription.resume,
    );
    if (_length > 0) raw.add(_take(_length));
    if (_peerClosed) unawaited(raw.close());
    unawaited(_socket.done.then((_) => _gone()));
    return StreamChannel(raw.stream, _socket.sink);
  }

  /// A graceful close of a hijacked connection: the FIN goes out after
  /// what the handler wrote, if the peer reads it.
  void _closeRaw() {
    if (_socket.isOpen) unawaited(_socket.sink.close());
  }

  void _append(final Uint8List data) {
    final needed = _length + data.length;
    if (needed > _buffer.length) {
      var size = _buffer.length * 2;
      while (size < needed) {
        size *= 2;
      }
      final grown = Uint8List(size);
      grown.setRange(0, _length, _buffer);
      _buffer = grown;
    }
    _buffer.setRange(_length, needed, data);
    _length = needed;
  }

  Uint8List _take(final int n) {
    final out = _buffer.sublist(0, n);
    _consume(n);
    return out;
  }

  void _consume(final int n) {
    if (n == 0) return;
    _buffer.setRange(0, _length - n, _buffer, n);
    _length -= n;
  }
}

/// One request on a simulated connection and the response that goes back.
final class _SimExchange implements AdapterExchange {
  final _Connection _connection;
  final RequestHead _head;
  final Uint8List? _bytes;
  final Stream<Uint8List>? _stream;
  final int? _contentLength;

  ExchangeEnd? _end;
  Completer<ExchangeEnd>? _done;
  Completer<void>? _cancelled;
  var _answered = false;
  StreamSubscription<Uint8List>? _outbound;
  Completer<void>? _streaming;

  /// How much may be queued for the wire before the body stream pauses.
  static const _highWater = 256 << 10;
  static const _lowWater = 64 << 10;

  _SimExchange(
    this._connection,
    this._head, {
    final Uint8List? bytes,
    final Stream<Uint8List>? stream,
    final int? contentLength,
  }) : _bytes = bytes,
       _stream = stream,
       _contentLength = contentLength;

  @override
  HttpProtocol get protocol => _head.protocol;

  @override
  Request toRequest(final RequestFactory create) {
    final headers = Headers.fromStore(
      ByteHeaderStore(_head.bytes, _head.slots),
    );
    final (target, scheme, authority) = _parseTarget();
    final socket = _connection._socket;
    return create(
      _head.method,
      this,
      target: target..validate(),
      authority: authority ?? _head.host ?? _connection._adapter.authority,
      scheme: scheme ?? 'http',
      headers: headers,
      body: Body.of(
        headers.tryGet(Headers.contentType),
        bytes: _bytes,
        stream: _stream,
        contentLength: _contentLength,
      ),
      lazyConnectionInfo: () => ConnectionInfo(
        remote: SocketAddress(
          address: IPv4Address.loopback,
          port: socket.remotePort,
        ),
        localPort: socket.localPort,
      ),
    );
  }

  /// The target split into a [RequestTarget] and, for an absolute-form
  /// target, its scheme and authority. The asterisk and authority forms
  /// throw, and the core answers 400.
  (RequestTarget, String?, String?) _parseTarget() {
    final target = _head.target;
    var pathStart = 0;
    String? scheme;
    String? authority;
    if (target.isEmpty || target[0] != 0x2f) {
      final text = String.fromCharCodes(target);
      final schemeEnd = text.indexOf('://');
      if (schemeEnd <= 0 ||
          !RegExp(
            r'^[A-Za-z][A-Za-z0-9+.-]*$',
          ).hasMatch(text.substring(0, schemeEnd))) {
        throw FormatException(
          'Not an origin-form or absolute-form target',
          text,
        );
      }
      scheme = text.substring(0, schemeEnd).toLowerCase();
      var authorityEnd = schemeEnd + 3;
      while (authorityEnd < text.length &&
          text[authorityEnd] != '/' &&
          text[authorityEnd] != '?') {
        authorityEnd++;
      }
      authority = text.substring(schemeEnd + 3, authorityEnd);
      if (authority.isEmpty) {
        throw FormatException('An absolute-form target has an authority', text);
      }
      pathStart = authorityEnd;
    }
    var query = target.length;
    for (var i = pathStart; i < target.length; i++) {
      if (target[i] == 0x3f) {
        query = i;
        break;
      }
    }
    final path = pathStart == query
        ? Uint8List.fromList(const [0x2f])
        : Uint8List.sublistView(target, pathStart, query);
    return (
      RequestTarget.fromBytes(
        path,
        query == target.length
            ? null
            : Uint8List.sublistView(target, query + 1),
      ),
      scheme,
      authority,
    );
  }

  @override
  FutureOr<void> respond(final Response response) {
    if (_end != null) {
      if (_end == ExchangeEnd.aborted || _end == ExchangeEnd.cancelledByPeer) {
        return null;
      }
      throw StateError('The exchange was already answered');
    }
    if (_answered) throw StateError('The exchange was already answered');
    final framing = ResponseFraming.of(
      response,
      head: _head.method == Method.head,
      protocol: protocol,
      keepAlive: _head.keepAlive && _connection._reusable,
    );
    final head = encodeResponseHead(response, framing);
    final body = response.body;
    final bytes = body.bytes;
    if (!framing.sendBody || bytes != null || body.contentLength == 0) {
      body.read();
      _answered = true;
      _connection._write(head);
      if (framing.sendBody && bytes != null) _connection._write(bytes);
      _complete(framing);
      return null;
    }
    // Reads before the head goes out: a body that was read already throws
    // here, while the exchange is still open for the 500.
    final chunks = body.read();
    _answered = true;
    _connection._write(head);
    final finished = _streaming = Completer<void>();
    final socket = _connection._socket;
    _outbound = chunks.listen(
      (final chunk) {
        if (chunk.isEmpty) return;
        _connection._write(framing.chunked ? encodeChunk(chunk) : chunk);
        if (socket.pendingBytes > _highWater) {
          _outbound?.pause();
          socket.onDrain = () {
            if (socket.pendingBytes < _lowWater) {
              socket.onDrain = null;
              _outbound?.resume();
            }
          };
        }
      },
      onDone: () {
        _outbound = null;
        socket.onDrain = null;
        if (framing.chunked) _connection._write(lastChunk);
        _complete(framing);
        finished.complete();
      },
      onError: (final Object error, final StackTrace stackTrace) {
        _outbound = null;
        socket.onDrain = null;
        _connection._sim.record('adapter', 'response body failed: $error');
        _connection._destroy(end: ExchangeEnd.aborted);
        finished.completeError(error, stackTrace);
      },
      cancelOnError: true,
    );
    return finished.future;
  }

  void _complete(final ResponseFraming framing) {
    if (_end != null) return;
    _finish(ExchangeEnd.completed);
    if (framing.closeAfter) _connection._reusable = false;
    _connection._exchangeFinished();
  }

  @override
  FutureOr<StreamChannel<Uint8List>> hijack() {
    if (_end != null || _answered) {
      throw StateError('The exchange was already answered');
    }
    if (!_connection._bodyDone) {
      throw StateError(
        'The request body streams and was not read to its end. '
        'Read the body before hijacking',
      );
    }
    _answered = true;
    _finish(ExchangeEnd.hijacked);
    return _connection._detach();
  }

  @override
  FutureOr<RelicWebSocket> upgradeWebSocket(final String acceptKey) =>
      throw UnsupportedError('SimAdapter frames WebSockets over hijack');

  @override
  void abort() {
    if (_end != null) return;
    _connection._sim.record('adapter', '${_connection.label} aborted');
    _connection._destroy(end: ExchangeEnd.aborted);
  }

  @override
  Future<void> get cancelled => _end == ExchangeEnd.cancelledByPeer
      ? Future.value()
      : (_cancelled ??= Completer<void>()).future;

  @override
  Future<ExchangeEnd> get done {
    final end = _end;
    if (end != null) return Future.value(end);
    return (_done ??= Completer<ExchangeEnd>()).future;
  }

  /// The connection ended under the exchange, by the peer or the adapter.
  void _ended(final ExchangeEnd end) {
    _finish(end);
    final outbound = _outbound;
    if (outbound != null) {
      _outbound = null;
      unawaited(outbound.cancel());
      _streaming?.completeError(const SimConnectionReset());
    }
  }

  void _finish(final ExchangeEnd end) {
    if (_end != null) return;
    _end = end;
    _done?.complete(end);
    if (end == ExchangeEnd.cancelledByPeer) _cancelled?.complete();
  }
}
