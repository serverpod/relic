import 'dart:async';
import 'dart:collection';
import 'dart:ffi';
import 'dart:io' as io;
import 'dart:isolate';
import 'dart:typed_data';

import 'package:ffi/ffi.dart';
import 'package:relic_core/relic_core.dart';
import 'package:stream_channel/stream_channel.dart';

import 'bindings.dart' as native;
import 'response_encoder.dart';

/// An [Adapter] backed by the Zig HTTP server in `src/relic_native.zig`.
///
/// The native side accepts connections on a thread of its own, and parses
/// requests and writes responses on this isolate's thread while [_drain]
/// ticks it. Each request reaches this isolate as one [NativeExchange]
/// through a queue, with one wake per idle-to-busy transition, and goes
/// back as encoded bytes the native side writes.
///
/// Several isolates share one server by binding with the same [group].
/// The first bind creates it, later binds attach to it, and the last
/// [close] stops it. `serveNative` mints a group per call.
final class NativeAdapter implements Adapter {
  final Pointer<Void> _server;
  final Pointer<Void> _reactor;
  final int _slot;
  final RawReceivePort _wake;
  final io.InternetAddress address;
  final int _port;
  final _out = calloc<Pointer<native.ExchangeView>>(_batchSize);

  /// Scratch for the three results of relic_read_chunk, reused by every
  /// pull. A pull never re-enters.
  final _chunkData = calloc<Pointer<Uint8>>();
  final _chunkLength = calloc<Size>();
  final _chunkStatus = calloc<Uint8>();

  /// The exchanges a handler has not answered. A list each exchange is a
  /// link of, so one comes and goes with a few field writes.
  final _inFlight = LinkedList<NativeExchange>();

  /// Connections a handler took over as raw channels. They are no longer
  /// exchanges the drain waits for, but still connections to close.
  final _hijacked = <NativeExchange>{};

  /// Exchanges by the address of their native view, for the events the
  /// native side posts about one exchange. Only those that can get one
  /// are here: see [NativeExchange._expectEvents].
  final _byAddress = <int, NativeExchange>{};
  ExchangeSink? _sink;
  var _closing = false;
  var _closed = false;
  Completer<void>? _drained;
  Completer<void>? _released;

  /// Exchanges taken per poll.
  static const _batchSize = 64;

  /// Polls per wake before yielding to the event loop, so timers and other
  /// I/O get a turn while requests keep coming.
  static const _batchesPerTurn = 4;

  /// How long a graceful close waits for in-flight exchanges before it
  /// aborts them. The same ceiling as the dart:io adapter's.
  static const _drainTimeout = Duration(seconds: 5);

  NativeAdapter._(this._server, this._reactor, this._wake, this.address)
    : _port = native.serverPort(_server),
      _slot = native.reactorSlot(_reactor),
      _authority = _listenerAuthority(address, native.serverPort(_server));

  /// The authority of a request without a Host, which HTTP/1.0 allows:
  /// the listener itself, bracketed when it is an IPv6 address.
  final String _authority;

  static String _listenerAuthority(io.InternetAddress address, int port) {
    final host = address.type == io.InternetAddressType.IPv6
        ? '[${address.address}]'
        : address.address;
    return '$host:$port';
  }

  /// Binds a server on [address] and [port], or joins the one another
  /// isolate created for [group].
  ///
  /// The adapter's reactor runs on this isolate's thread, in ticks the
  /// adapter drives from its event loop. [reactorCapacity] is how many
  /// isolates may attach. A body up to [maxInlineBody] bytes is read
  /// before the request is handed over. A larger or chunked one streams
  /// to the handler as it arrives.
  ///
  /// A connection may wait [idleTimeout] for the first byte of a request,
  /// and the rest of the head must arrive within [headerTimeout] of that
  /// byte, which bounds a slowloris. [bodyTimeout] and [writeTimeout] are
  /// inactivity limits on reading a body and writing a response. A
  /// head or a body that times out answers 408 and closes, and the other
  /// timeouts close without a response. [Duration.zero] disables a limit.
  /// [maxConnections] caps the connections accepted at once, 0 for none.
  ///
  /// Throws [UnsupportedError] on a platform without the native library,
  /// and [io.SocketException] when the port cannot be bound.
  static Future<NativeAdapter> bind(
    io.InternetAddress address, {
    int port = 0,
    String? group,
    int reactorCapacity = 64,
    int maxInlineBody = 1 << 20,
    int backlog = 128,
    int maxConnections = 0,
    Duration idleTimeout = const Duration(seconds: 60),
    Duration headerTimeout = const Duration(seconds: 10),
    Duration bodyTimeout = const Duration(seconds: 30),
    Duration writeTimeout = const Duration(seconds: 30),
  }) async {
    _initDartApi();
    final options = calloc<native.Options>();
    final ip = address.address.toNativeUtf8();
    final groupText = group?.toNativeUtf8() ?? nullptr;
    final Pointer<Void> server;
    try {
      options.ref
        ..reactorCapacity = reactorCapacity
        ..backlog = backlog
        ..maxConnections = maxConnections
        ..maxInlineBody = maxInlineBody
        ..idleTimeoutMs = idleTimeout.inMilliseconds
        ..headerTimeoutMs = headerTimeout.inMilliseconds
        ..bodyTimeoutMs = bodyTimeout.inMilliseconds
        ..writeTimeoutMs = writeTimeout.inMilliseconds;
      server = native.serverBind(groupText.cast(), ip.cast(), port, options);
    } finally {
      calloc.free(options);
      calloc.free(ip);
      if (groupText != nullptr) calloc.free(groupText);
    }
    if (server == nullptr) {
      throw io.SocketException(
        'relic_native could not bind',
        address: address,
        port: port,
      );
    }
    final wake = RawReceivePort(null, 'relic_native');
    final reactor = native.reactorCreate(server, wake.sendPort.nativePort);
    if (reactor == nullptr) {
      wake.close();
      throw StateError(
        'relic_native: every reactor slot of the server for group "$group" '
        'is taken (reactorCapacity: $reactorCapacity)',
      );
    }
    return NativeAdapter._(server, reactor, wake, address);
  }

  static var _dartApiReady = false;

  static void _initDartApi() {
    if (_dartApiReady) return;
    final int rc;
    try {
      rc = native.initDartApi(NativeApi.initializeApiDLData);
    } on ArgumentError catch (e) {
      throw UnsupportedError(
        'relic_native has no native library for this platform: $e',
      );
    }
    if (rc != 0) {
      throw StateError('relic_native: Dart_InitializeApiDL failed ($rc)');
    }
    _dartApiReady = true;
  }

  @override
  AdapterCapabilities get capabilities =>
      const AdapterCapabilities(hijack: true);

  @override
  List<Listener> get listeners => [
    Listener(Transport.tcp, address.address, _port, const {
      HttpProtocol.http10,
      HttpProtocol.http11,
    }),
  ];

  @override
  void start(ExchangeSink sink) {
    if (_sink != null) throw StateError('start was already called');
    _sink = sink;
    // 0 from the waiter thread, when the loop has events or a timer is
    // due. 1 from this isolate, a drain it scheduled on itself. A raw
    // port's handler runs in whatever zone is current when the message
    // lands, so it is bound to the zone that started the server, which
    // is where handlers expect to run, as dart:io's listen does.
    final zone = Zone.current;
    _wake.handler = (_) => zone.runGuarded(_drain);
    _scheduleDrain();
  }

  var _drainScheduled = false;
  var _inDrain = false;
  var _drainAgain = false;

  /// Set by a close called from inside the drain, which the drain
  /// completes on its way out.
  Completer<void>? _drainReturned;

  /// A tick is due: something was handed to the native side that the
  /// reactor acts on at its next pass. From inside the drain, a sync
  /// handler answering for one, the drain itself takes it on its next
  /// batch. From anywhere else it is a turn of the event loop away, as
  /// a message to this isolate's own port. A zero Timer goes through
  /// the dart:io event handler thread and back, 10 us on that thread
  /// per hop, where the port message stays in this isolate.
  void _scheduleDrain() {
    if (_closed) return;
    if (_inDrain) {
      _drainAgain = true;
      return;
    }
    if (_drainScheduled) return;
    _drainScheduled = true;
    _wake.sendPort.send(1);
  }

  /// Ticks the reactor until it has nothing left, then arms the waiter,
  /// or hands back to the event loop once a handler has an answer
  /// pending or after a few batches, so timers and the handlers' own I/O
  /// get a turn.
  void _drain() {
    _drainScheduled = false;
    final sink = _sink;
    if (sink == null || _closed) return;
    _inDrain = true;
    var handedOver = false;
    try {
      for (var batch = 0; batch < _batchesPerTurn; batch++) {
        _drainAgain = false;
        final n = native.reactorTick(_reactor, 0, _out, _batchSize);
        if (_takeExchanges(n, sink)) handedOver = true;
        if (_dispatchEvents()) handedOver = true;
        if (n > 0 || _drainAgain || native.reactorPending(_reactor)) continue;
        // What this turn handed to Dart may answer from a microtask: an
        // async handler, or a stream listener such as the WebSocket
        // framer. Those run when the drain returns, so the turn ends here
        // and the next one picks their writes up. A sync handler has
        // answered already and does not end the turn.
        if (handedOver) break;
        // Nothing to do. One tick that waits in the kernel for a moment
        // catches the next request without a thread handoff, which is
        // what a busy reactor sees next. Only after that does the isolate
        // park on the waiter and its port message.
        _drainAgain = false;
        final m = native.reactorTick(
          _reactor,
          _linger.inMilliseconds,
          _out,
          _batchSize,
        );
        if (_takeExchanges(m, sink)) handedOver = true;
        if (_dispatchEvents()) handedOver = true;
        if (m > 0 || _drainAgain || native.reactorPending(_reactor)) continue;
        native.reactorWait(_reactor);
        return;
      }
    } finally {
      _inDrain = false;
      _settle(_drainReturned);
    }
    _scheduleDrain();
  }

  /// How long an idle tick waits in the kernel before the isolate parks.
  /// The event loop is held for at most this long, which is what a timer
  /// or a handler's own I/O can be late by while the reactor is idle.
  static const _linger = Duration(milliseconds: 1);

  /// Hands [n] new exchanges to [sink]. True when one of them is still
  /// being handled, by a handler that is async.
  bool _takeExchanges(int n, ExchangeSink sink) {
    var async = false;
    for (var i = 0; i < n; i++) {
      if (_closing) {
        // Whatever arrives while draining is dropped at once, so a client
        // sees a closed connection and not a hang until the reactor is
        // destroyed.
        native.abort(_out[i]);
        continue;
      }
      final exchange = NativeExchange._(this, _out[i]);
      _inFlight.add(exchange);
      if (exchange._bodyStreamed) exchange._expectEvents();
      final pending = sink(exchange);
      if (pending is Future<void>) {
        async = true;
        unawaited(pending);
      }
    }
    return async;
  }

  /// Hands the events the native side posted to their exchanges. An
  /// event is the address of a view, with the low bit set for the last
  /// event of a raw connection, whose view is about to die. True when
  /// there was at least one.
  bool _dispatchEvents() {
    final events = _out.cast<Size>();
    var any = false;
    while (true) {
      final m = native.reactorEvents(_reactor, events, _batchSize);
      if (m > 0) any = true;
      for (var i = 0; i < m; i++) {
        final tagged = events[i];
        _byAddress[tagged & ~1]?._onEvent(last: tagged & 1 != 0);
      }
      if (m < _batchSize) return any;
    }
  }

  void _finished(NativeExchange exchange) {
    _inFlight.remove(exchange);
    _hijacked.remove(exchange);
    if (exchange._expectsEvents) _byAddress.remove(exchange._address);
    if (_inFlight.isEmpty) _settle(_drained);
    if (_hijacked.isEmpty) _settle(_released);
  }

  /// Completes a close-path waiter the first time its set empties. A
  /// connection that ends later, while the close still waits on the
  /// other set or aborts the rest, finds it completed.
  static void _settle(Completer<void>? waiter) {
    if (waiter != null && !waiter.isCompleted) waiter.complete();
  }

  /// The exchange became a raw channel: the drain no longer waits for it,
  /// and the close path takes it down with the other connections.
  void _tookOver(NativeExchange exchange) {
    _inFlight.remove(exchange);
    _hijacked.add(exchange);
    if (_inFlight.isEmpty) _settle(_drained);
  }

  @override
  Future<void> close({bool force = false}) async {
    if (_closing) return _closedFuture.future;
    _closing = true;
    if (_inDrain) {
      // A handler is closing its own server. The drain's batch still
      // reads the buffers and ticks the reactor that are freed below.
      final returned = _drainReturned = Completer<void>();
      await returned.future;
    }
    if (!force) {
      if (_inFlight.isNotEmpty) {
        final drained = _drained = Completer<void>();
        await drained.future.timeout(_drainTimeout, onTimeout: () {});
      }
      if (_hijacked.isNotEmpty) {
        // A hijacked connection closes once what its handler wrote is
        // flushed. One whose peer stopped reading never gets there, and
        // the abort below drops it.
        final released = _released = Completer<void>();
        for (final exchange in _hijacked.toList()) {
          unawaited(exchange._rawSink?.close());
        }
        await released.future.timeout(_drainTimeout, onTimeout: () {});
      }
    }
    for (final exchange in _inFlight.toList()) {
      exchange.abort();
    }
    for (final exchange in _hijacked.toList()) {
      exchange.abort();
    }
    _closed = true;
    _wake.close();
    // Blocks while the connections unwind. The last reactor of a server
    // stops the server too, and waits for its thread.
    native.reactorDestroy(_reactor);
    calloc.free(_out);
    calloc.free(_chunkData);
    calloc.free(_chunkLength);
    calloc.free(_chunkStatus);
    _closedFuture.complete();
  }

  final _closedFuture = Completer<void>();

  /// The server's connections, reported by one isolate.
  ///
  /// The isolates of one group share one native server, and the core sums
  /// their reports. The lowest attached isolate reports the server-wide
  /// counts and the others report zero, so the sum is one snapshot.
  @override
  ConnectionsInfo get connectionsInfo {
    if (_closed) return (active: 0, closing: 0, idle: 0);
    final stats = calloc<native.Stats>();
    try {
      native.serverStats(_server, stats);
      if (stats.ref.firstAttached != _slot) {
        return (active: 0, closing: 0, idle: 0);
      }
      return (active: stats.ref.active, closing: 0, idle: stats.ref.idle);
    } finally {
      calloc.free(stats);
    }
  }
}

/// One request received by the native side and the response that goes back.
///
/// Everything the request side needs is copied out of native memory when
/// the exchange is taken from the queue, so the [Request] built from it is
/// plain Dart data with no lifetime tied to the connection. A streamed
/// body is the exception: its chunks are pulled while the handler runs.
final class NativeExchange extends LinkedListEntry<NativeExchange>
    implements AdapterExchange {
  final NativeAdapter _adapter;
  Pointer<native.ExchangeView>? _view;
  final int _address;

  /// The view while the connection is a raw channel, after [hijack].
  Pointer<native.ExchangeView>? _rawView;
  _RawSink? _rawSink;

  /// The sink was closed and the native side flushes. Nothing is read
  /// from the view until its last event says the connection is gone.
  var _rawClosing = false;

  /// The request body handed to the handler, to tell whether it read it.
  Body? _bodyObject;

  /// How the exchange ended, once it has.
  ExchangeEnd? _end;
  Completer<void>? _cancelled;
  final int _method;
  final int _version;
  final bool _keepAlive;
  final Uint8List _remoteAddress;
  final int _remotePort;
  final int _localPort;
  final Uint8List _head;
  final Int32List _slots;
  final int _targetOff;
  final int _targetLen;
  final Uint8List? _body;
  final bool _bodyStreamed;
  final int _bodyLen;

  /// The completer behind [done], for a caller that asked before the end.
  Completer<ExchangeEnd>? _done;

  /// The inbound body stream, while a streamed request body is being
  /// pulled.
  StreamController<Uint8List>? _inbound;

  /// The streamed request body was pulled to its end.
  var _bodyRead = false;

  /// The outbound body subscription, while a streamed response goes out.
  StreamSubscription<Uint8List>? _outbound;
  var _outSent = 0;

  /// Outbound chunks handed over and not yet written, before the stream
  /// is paused until the native side catches up.
  static const _outWindow = 8;

  static final _noBytes = Uint8List(0);

  NativeExchange._(NativeAdapter adapter, Pointer<native.ExchangeView> view)
    : this._from(adapter, view, view.ref);

  /// Reads the view once: every `ref` builds a struct view of its own.
  NativeExchange._from(
    this._adapter,
    Pointer<native.ExchangeView> view,
    native.ExchangeView ref,
  ) : _view = view,
      _address = view.address,
      _method = ref.method,
      _version = ref.version,
      _keepAlive = ref.keepAlive != 0,
      _remoteAddress = _addressBytes(ref),
      _remotePort = ref.remotePort,
      _localPort = ref.localPort,
      _head = Uint8List.fromList(ref.head.asTypedList(ref.headLen)),
      _slots = Int32List.fromList(
        ref.headers.cast<Int32>().asTypedList(ref.headerCount * 4),
      ),
      _targetOff = ref.targetOff,
      _targetLen = ref.targetLen,
      _bodyStreamed = ref.bodyStreamed != 0,
      _bodyLen = ref.bodyLen,
      _body = ref.body == nullptr || ref.bodyLen == 0
          ? null
          : Uint8List.fromList(ref.body.asTypedList(ref.bodyLen));

  static Uint8List _addressBytes(native.ExchangeView view) {
    final length = view.remoteFamily == 4 ? 4 : 16;
    final bytes = Uint8List(length);
    for (var i = 0; i < length; i++) {
      bytes[i] = view.remoteAddr[i];
    }
    return bytes;
  }

  @override
  HttpProtocol get protocol =>
      _version == 0 ? HttpProtocol.http10 : HttpProtocol.http11;

  Method get method => _methods[_method];

  /// Indexed by `dartMethod` of src/relic_native.zig.
  static const _methods = [
    Method.get,
    Method.head,
    Method.post,
    Method.put,
    Method.delete,
    Method.connect,
    Method.options,
    Method.trace,
    Method.patch,
  ];

  @override
  Request toRequest() {
    final headers = Headers.fromStore(ByteHeaderStore(_head, _slots));
    final (target, scheme, authority) = _parseTarget();
    return RequestInternal.create(
      method,
      null,
      this,
      target: target..validate(),
      // The Host header, or the listener for a request without one, which
      // HTTP/1.0 allows.
      authority:
          authority ?? headers.value(HeaderName.host) ?? _adapter._authority,
      scheme: scheme ?? 'http',
      protocol: protocol,
      headers: headers,
      body: _bodyObject = Body.ofRequest(
        headers,
        bytes: _body,
        stream: _bodyStreamed ? _inboundStream() : null,
        // A chunked body has no declared length.
        contentLength: _bodyStreamed && _bodyLen != 0 ? _bodyLen : null,
      ),
      lazyConnectionInfo: _connectionInfo,
    );
  }

  ConnectionInfo _connectionInfo() => ConnectionInfo(
    remote: SocketAddress(
      address: IPAddress.fromBytes(_remoteAddress),
      port: _remotePort,
    ),
    localPort: _localPort,
  );

  /// The target bytes as a [RequestTarget], split at the first `?`, with
  /// the scheme and authority an absolute-form target carries: an origin
  /// server uses those over the Host header (RFC 9112 3.2.2). The
  /// fragment and decoding checks are the target's own.
  ///
  /// The asterisk and authority forms are not served. They throw, and
  /// the core answers 400, as the dart:io adapter does.
  (RequestTarget, String?, String?) _parseTarget() {
    final end = _targetOff + _targetLen;
    var pathStart = _targetOff;
    String? scheme;
    String? authority;
    if (_targetLen == 0 || _head[_targetOff] != 0x2f) {
      final text = String.fromCharCodes(_head, _targetOff, end);
      final schemeEnd = text.indexOf('://');
      if (schemeEnd <= 0 ||
          !_schemePattern.hasMatch(text.substring(0, schemeEnd))) {
        throw FormatException(
          'Not an origin-form or absolute-form request target',
          text,
        );
      }
      scheme = text.substring(0, schemeEnd).toLowerCase();
      var authorityEnd = schemeEnd + 3;
      while (authorityEnd < text.length &&
          text.codeUnitAt(authorityEnd) != 0x2f &&
          text.codeUnitAt(authorityEnd) != 0x3f) {
        authorityEnd++;
      }
      authority = text.substring(schemeEnd + 3, authorityEnd);
      if (authority.isEmpty) {
        throw FormatException(
          'An absolute-form request target has an authority',
          text,
        );
      }
      pathStart = _targetOff + authorityEnd;
    }
    var query = end;
    for (var i = pathStart; i < end; i++) {
      if (_head[i] == 0x3f) {
        query = i;
        break;
      }
    }
    // An absolute-form target with an empty path is the root.
    final path = pathStart == query
        ? _rootPath
        : Uint8List.sublistView(_head, pathStart, query);
    return (
      RequestTarget.fromBytes(
        path,
        query == end ? null : Uint8List.sublistView(_head, query + 1, end),
      ),
      scheme,
      authority,
    );
  }

  static final _schemePattern = RegExp(r'^[A-Za-z][A-Za-z0-9+.-]*$');
  static final _rootPath = Uint8List.fromList([0x2f]);

  /// The streamed request body, pulled from the native inbound queue as
  /// the listener wants it. Pausing the stream stops the pulling, which
  /// stops the credit, which stops the fiber reading ahead.
  Stream<Uint8List> _inboundStream() {
    final controller = StreamController<Uint8List>(
      onListen: _pullInbound,
      onResume: _pullInbound,
    );
    _inbound = controller;
    return controller.stream;
  }

  void _pullInbound() {
    final controller = _inbound;
    final view = _view ?? _streamView ?? _rawView;
    if (controller == null || controller.isClosed) return;
    if (view == null) {
      // Answered before the body was read. The native side drains the
      // rest or closes the connection (max_discard in relic_native.zig).
      unawaited(controller.close());
      return;
    }
    final data = _adapter._chunkData;
    final length = _adapter._chunkLength;
    final status = _adapter._chunkStatus;
    try {
      while (!controller.isPaused && !controller.isClosed) {
        if (native.readChunk(view, data, length, status) == 0) return;
        final pointer = data.value;
        if (pointer != nullptr) {
          final chunk = Uint8List.fromList(pointer.asTypedList(length.value));
          native.free(pointer);
          controller.add(chunk);
        }
        switch (status.value) {
          case 1:
            _bodyRead = true;
            unawaited(controller.close());
          case 2:
            controller.addError(
              const io.SocketException('The request body ended early'),
            );
            unawaited(controller.close());
        }
      }
    } finally {
      // Credit went back to the reader, which the next tick acts on.
      _adapter._scheduleDrain();
    }
  }

  /// A response to an exchange the adapter already aborted, or whose peer
  /// hung up, goes nowhere and is not an error: the handler could not
  /// know. A second response to one that was answered is a bug.
  @override
  FutureOr<void> respond(Response response) {
    if (_view == null) {
      if (_end == ExchangeEnd.aborted || _end == ExchangeEnd.cancelledByPeer) {
        return null;
      }
      throw StateError('The exchange was already answered');
    }
    final framing = ResponseFraming.of(
      response,
      head: method == Method.head,
      protocol: protocol,
      keepAlive: _keepAlive,
    );
    final body = response.body;
    final bytes = body.bytes;
    if (!framing.sendBody || bytes != null || body.contentLength == 0) {
      // Nothing to stream. A body is read once, sent or not.
      body.consume();
      _write(
        response,
        framing,
        framing.sendBody ? bytes ?? _noBytes : _noBytes,
      );
      return null;
    }
    return _stream(response, framing);
  }

  /// The head encoded into native memory, with the view taken last: a
  /// head that does not encode leaves the exchange open for the 500 the
  /// core sends next.
  (Pointer<native.ExchangeView>, Pointer<Uint8>, int) _encodeHead(
    Response response,
    ResponseFraming framing,
  ) {
    final (headBuffer, headLength) = _nativeHead(
      ResponseHead(response, framing),
    );
    return (_takeView(), headBuffer, headLength);
  }

  void _write(Response response, ResponseFraming framing, Uint8List bytes) {
    final head = ResponseHead(response, framing);
    if (_writeInline(head, framing, bytes)) return;
    final (headBuffer, headLength) = _nativeHead(head);
    final view = _takeView();
    var bodyBuffer = nullptr.cast<Uint8>();
    if (bytes.isNotEmpty) bodyBuffer = _nativeCopy(bytes);
    native.respond(
      view,
      headBuffer,
      headLength,
      bodyBuffer,
      bytes.length,
      framing.closeAfter,
    );
    _adapter._scheduleDrain();
    _finish(ExchangeEnd.completed);
  }

  /// Sends the head now and the body as its stream produces it, chunked
  /// on the wire when the length is unknown. Completes when the last chunk
  /// was handed over, or fails when the body stream failed, in which case
  /// the connection is dropped since the message cannot be finished.
  Future<void> _stream(Response response, ResponseFraming framing) {
    final body = response.body;
    // Reads before the head goes out: a body that was already read throws
    // here, while the exchange is still open for the 500.
    final chunks = body.read();
    final (view, headBuffer, headLength) = _encodeHead(response, framing);
    _streamView = view;
    _expectEvents();
    native.respondStream(
      view,
      headBuffer,
      headLength,
      framing.closeAfter,
      framing.chunked,
    );
    _adapter._scheduleDrain();
    final finished = _streamDone = Completer<void>();
    _outbound = chunks.listen(
      (chunk) {
        if (chunk.isEmpty) return;
        final buffer = _nativeCopy(chunk);
        _adapter._scheduleDrain();
        if (!native.writeChunk(view, buffer, chunk.length)) {
          native.free(buffer);
          _failStream(view, StateError('relic_native: out of memory'));
          return;
        }
        _outSent++;
        if (_outSent - view.ref.chunksWritten >= _outWindow) {
          _outbound?.pause();
        }
      },
      onDone: () {
        _outbound = null;
        native.finishStream(view, true);
        _adapter._scheduleDrain();
        _finish(ExchangeEnd.completed);
        finished.complete();
      },
      onError: (Object error, StackTrace stackTrace) {
        _failStream(view, error, stackTrace);
      },
      cancelOnError: true,
    );
    return finished.future;
  }

  Pointer<native.ExchangeView>? _streamView;

  /// The future [respond] returned for a streamed response, while the
  /// stream is being written.
  Completer<void>? _streamDone;

  /// Ends a streamed response that cannot be finished. The native side
  /// drops the connection, and the respond that streamed it fails with
  /// [error], or with the dropped connection when the body itself was
  /// fine.
  void _failStream(
    Pointer<native.ExchangeView> view, [
    Object? error,
    StackTrace? stackTrace,
  ]) {
    unawaited(_outbound?.cancel());
    _outbound = null;
    native.finishStream(view, false);
    _adapter._scheduleDrain();
    _finish(ExchangeEnd.aborted);
    final done = _streamDone;
    _streamDone = null;
    if (done != null && !done.isCompleted) {
      done.completeError(
        error ??
            const io.SocketException(
              'The connection closed before the body was sent',
            ),
        stackTrace,
      );
    }
  }

  /// Encodes the head and [bytes] straight into the connection's write
  /// buffer when both fit, which spares the two allocations and the copy
  /// of the other path. False when they do not fit or the buffer is in
  /// use. As there, the view is taken last.
  bool _writeInline(
    ResponseHead head,
    ResponseFraming framing,
    Uint8List bytes,
  ) {
    final pending = _view;
    if (pending == null) return false;
    final scratch = pending.ref.scratch;
    final capacity = pending.ref.scratchCap;
    if (scratch == nullptr || head.bound + bytes.length > capacity) {
      return false;
    }
    final out = scratch.asTypedList(capacity);
    final headLength = head.writeTo(out);
    out.setRange(headLength, headLength + bytes.length, bytes);
    native.respondInline(
      _takeView(),
      headLength + bytes.length,
      framing.closeAfter,
    );
    _adapter._scheduleDrain();
    _finish(ExchangeEnd.completed);
    return true;
  }

  /// The head written into the buffer the native side takes over, and
  /// its length.
  static (Pointer<Uint8>, int) _nativeHead(ResponseHead head) {
    final buffer = native.alloc(head.bound);
    try {
      return (buffer, head.writeTo(buffer.asTypedList(head.bound)));
    } catch (_) {
      native.free(buffer);
      rethrow;
    }
  }

  static Pointer<Uint8> _nativeCopy(Uint8List bytes) {
    final buffer = native.alloc(bytes.length);
    buffer.asTypedList(bytes.length).setAll(0, bytes);
    return buffer;
  }

  /// Takes the connection over as a raw byte channel. Nothing has been
  /// written to the peer, so the handler writes the whole response, or
  /// whatever protocol it speaks instead. An inline request body the
  /// handler did not read comes first on the stream, as the dart:io
  /// adapter does it. Closing the sink closes the connection once what
  /// was written is flushed.
  ///
  /// A streamed request body (chunked, or over the inline limit) must be
  /// read to its end first. The native reader is past the head by the
  /// time the handler runs, and what it decoded cannot go back on the
  /// wire.
  @override
  StreamChannel<Uint8List> hijack() {
    if (_bodyStreamed && !_bodyRead) {
      throw StateError(
        'The request body streams and was not read to its end. '
        'Read it before hijacking the connection',
      );
    }
    final view = _takeView();
    _rawView = view;
    _expectEvents();
    native.hijack(view);
    _adapter._scheduleDrain();
    _adapter._tookOver(this);
    _complete(ExchangeEnd.hijacked);
    final unread = _body;
    final body = _bodyObject;
    final inbound = _inboundStream();
    final stream = unread != null && body != null && !body.isRead
        ? _prepend(unread, inbound)
        : inbound;
    final sink = _rawSink = _RawSink(this);
    return StreamChannel<Uint8List>(stream, sink);
  }

  static Stream<Uint8List> _prepend(
    Uint8List first,
    Stream<Uint8List> rest,
  ) async* {
    yield first;
    yield* rest;
  }

  /// Hands [data] to the native writer. Nothing happens on a connection
  /// that is already gone, as with a destroyed socket.
  void _writeRaw(Uint8List data) {
    final view = _rawView;
    if (view == null || _rawClosing || data.isEmpty) return;
    final buffer = _nativeCopy(data);
    _adapter._scheduleDrain();
    if (!native.writeChunk(view, buffer, data.length)) {
      native.free(buffer);
      _failRaw(const io.SocketException('relic_native: out of memory'));
    }
  }

  /// The sink was closed: the native side writes what is queued, closes
  /// the connection and posts one last event. Reading stops now.
  void _closeRaw() {
    final view = _rawView;
    if (view == null || _rawClosing) return;
    _rawClosing = true;
    native.finishStream(view, true);
    _adapter._scheduleDrain();
    final inbound = _inbound;
    if (inbound != null && !inbound.isClosed) unawaited(inbound.close());
  }

  /// Drops a raw connection. The stream ends, with [error] when there is
  /// one, and the native side frees the connection.
  void _failRaw([Object? error]) {
    final view = _rawView;
    if (view == null) return;
    _rawView = null;
    if (!_rawClosing) native.abort(view);
    _rawClosing = true;
    final inbound = _inbound;
    if (inbound != null && !inbound.isClosed) {
      if (error != null) inbound.addError(error);
      unawaited(inbound.close());
    }
    _rawSink?._ended();
    _adapter._finished(this);
  }

  /// The native side is done with a raw connection whose sink was closed.
  void _rawGone() {
    _rawView = null;
    _rawSink?._ended();
    _adapter._finished(this);
  }

  @override
  FutureOr<RelicWebSocket> upgradeWebSocket(String acceptKey) =>
      throw UnsupportedError('relic_native cannot upgrade to WebSocket yet');

  @override
  void abort() {
    if (_rawView != null) {
      _failRaw();
      return;
    }
    final streaming = _streamView;
    if (streaming != null && _outbound != null) {
      // The head went out. The body cannot be finished, so the last chunk
      // says so and the connection drops.
      _failStream(streaming);
      return;
    }
    final view = _view;
    if (view == null) return;
    _view = null;
    native.abort(view);
    _adapter._scheduleDrain();
    _finish(ExchangeEnd.aborted);
  }

  var _expectsEvents = false;

  /// Lists the exchange for the events the native side posts about it.
  /// It posts them for a streamed request body, a watched peer, a
  /// streamed response and a hijacked connection, so an exchange is
  /// listed before any of those starts. One that is answered from memory
  /// is never listed.
  void _expectEvents() {
    if (_expectsEvents) return;
    _expectsEvents = true;
    _adapter._byAddress[_address] = this;
  }

  /// The native view, once. The native side frees the exchange after
  /// respond or abort, so a second use would touch a dead frame.
  Pointer<native.ExchangeView> _takeView() {
    final view = _view;
    if (view == null) throw StateError('The exchange was already answered');
    _view = null;
    return view;
  }

  /// Completes when the peer hangs up before the response. The first read
  /// asks the native side to watch the connection, so the cost is paid
  /// only by handlers that want to know.
  @override
  Future<void> get cancelled {
    final cancelled = _cancelled;
    if (cancelled != null) return cancelled.future;
    final created = _cancelled = Completer<void>();
    final view = _view;
    if (view != null) {
      _expectEvents();
      native.watch(view);
    }
    return created.future;
  }

  /// An event about this exchange from the native side, while it is still
  /// in flight. The [last] one of a raw connection is posted by a frame
  /// about to die, so the view is not read.
  void _onEvent({required bool last}) {
    if (last) {
      if (_rawView != null) _rawGone();
      return;
    }
    // After the sink closed, what the peer still sends or its EOF is of
    // no interest, and the view is read only up to the last event.
    if (_rawClosing) return;
    final view = _view ?? _streamView ?? _rawView;
    if (view == null) return;
    if (_rawView != null && view.ref.writeFailed != 0) {
      _failRaw(const io.SocketException('The peer stopped reading'));
      return;
    }
    // A failed write is the peer gone while the response streams, which
    // is the only way the task sees it then, as with dart:io.
    if (view.ref.peerGone != 0 || view.ref.writeFailed != 0) {
      final cancelled = _cancelled;
      if (cancelled != null && !cancelled.isCompleted) cancelled.complete();
    }
    if (_inbound != null) _pullInbound();
    final outbound = _outbound;
    if (outbound != null) {
      if (view.ref.writeFailed != 0) {
        _failStream(view);
      } else if (outbound.isPaused &&
          _outSent - view.ref.chunksWritten < _outWindow) {
        outbound.resume();
      }
    }
  }

  @override
  Future<ExchangeEnd> get done {
    final end = _end;
    if (end != null) return Future.value(end);
    return (_done ??= Completer<ExchangeEnd>()).future;
  }

  void _finish(ExchangeEnd end) {
    _complete(end);
    _streamView = null;
    final inbound = _inbound;
    if (inbound != null && !inbound.isClosed) unawaited(inbound.close());
    _adapter._finished(this);
  }

  /// Records how the exchange ended, the first time it ends.
  void _complete(ExchangeEnd end) {
    if (_end != null) return;
    _end = end;
    _done?.complete(end);
  }
}

/// The sink of a hijacked connection. Bytes go to the native writer as
/// they are added, and closing it closes the connection after the flush.
final class _RawSink implements StreamSink<Uint8List> {
  final NativeExchange _exchange;
  final _done = Completer<void>();
  var _closed = false;

  _RawSink(this._exchange);

  @override
  void add(Uint8List data) {
    if (_closed) throw StateError('The channel sink is closed');
    _exchange._writeRaw(data);
  }

  @override
  void addError(Object error, [StackTrace? stackTrace]) {
    if (_closed) throw StateError('The channel sink is closed');
    _exchange._failRaw(error);
  }

  @override
  Future<void> addStream(Stream<Uint8List> stream) => stream.forEach(add);

  @override
  Future<void> close() {
    if (!_closed) {
      _closed = true;
      _exchange._closeRaw();
    }
    return _done.future;
  }

  void _ended() {
    _closed = true;
    if (!_done.isCompleted) _done.complete();
  }

  @override
  Future<void> get done => _done.future;
}
