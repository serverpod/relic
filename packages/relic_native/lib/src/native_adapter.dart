import 'dart:async';
import 'dart:collection';
import 'dart:convert';
import 'dart:ffi';
import 'dart:io' as io;
import 'dart:isolate';
import 'dart:math';
import 'dart:typed_data';

import 'package:ffi/ffi.dart';
import 'package:relic_core/relic_core.dart';
import 'package:stream_channel/stream_channel.dart';
import 'package:web_socket/web_socket.dart';

import 'bindings.dart' as native;
import 'response_encoder.dart';

part 'native_web_socket.dart';

/// The limits of a server [NativeAdapter.bind] starts, with the defaults
/// a server gets when none are given.
///
/// A connection may wait [idleTimeout] for the first byte of a request.
/// The rest of the head must arrive within [headerTimeout] of that byte,
/// which bounds a slowloris. [bodyTimeout] and [writeTimeout] are
/// inactivity limits on reading a body and writing a response. A head or
/// a body that times out answers 408 and closes. The other timeouts close
/// without a response. [Duration.zero] disables a limit.
final class NativeOptions {
  /// How many isolates may attach to the server.
  final int reactorCapacity;

  /// A body up to this many bytes is read before the request is handed
  /// over. A larger or chunked one streams to the handler as it arrives.
  final int maxInlineBody;

  /// The listen backlog.
  final int backlog;

  /// The connections accepted at once, 0 for no cap.
  final int maxConnections;

  final Duration idleTimeout;
  final Duration headerTimeout;
  final Duration bodyTimeout;
  final Duration writeTimeout;

  /// A WebSocket message over this many bytes closes the connection with
  /// 1009.
  final int maxWebSocketMessage;

  const NativeOptions({
    this.reactorCapacity = 64,
    this.maxInlineBody = 1 << 20,
    this.backlog = 128,
    this.maxConnections = 0,
    this.idleTimeout = const Duration(seconds: 60),
    this.headerTimeout = const Duration(seconds: 10),
    this.bodyTimeout = const Duration(seconds: 30),
    this.writeTimeout = const Duration(seconds: 30),
    this.maxWebSocketMessage = FramedWebSocket.defaultMaxMessageSize,
  });
}

/// The certificate chain and private key of an HTTPS server, as PEM.
///
/// [certificateChain] has the server's certificate first and any
/// intermediates after it. [privateKey] is an unencrypted PKCS#8 or SEC 1
/// key, ECDSA, RSA or Ed25519. The server speaks TLS 1.3 only, through
/// tls.zig.
final class NativeTls {
  final List<int> certificateChain;
  final List<int> privateKey;

  const NativeTls({required this.certificateChain, required this.privateKey});

  /// Reads both from PEM files.
  NativeTls.fromFiles({
    required final String certificateChain,
    required final String privateKey,
  }) : this(
         certificateChain: io.File(certificateChain).readAsBytesSync(),
         privateKey: io.File(privateKey).readAsBytesSync(),
       );
}

/// Mirrors `BindFailure` in src/relic_native.zig.
enum _BindFailure { none, bind, certificateChain, privateKey }

/// An [Adapter] backed by the Zig HTTP server in `src/relic_native.zig`.
///
/// The native side accepts connections on a thread of its own. It parses
/// requests and writes responses on this isolate's thread while [_drain]
/// ticks it. Each request reaches this isolate as one [NativeExchange]
/// through a queue, with one wake per idle-to-busy transition, and goes
/// back as encoded bytes the native side writes.
///
/// Several isolates share one server by passing [bind] the same group.
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

  /// The exchanges a handler has not answered. Each exchange is its own
  /// link, so one comes and goes with a few field writes.
  final _inFlight = LinkedList<NativeExchange>();

  /// Connections a handler took over, as raw channels or WebSockets. They
  /// are no longer exchanges the drain waits for, but still connections a
  /// forced close drops.
  final _hijacked = <NativeExchange>{};

  /// Exchanges by the address of their native view, for the events the
  /// native side posts about one exchange. Only those that can get one
  /// are listed, see [NativeExchange._expectEvents].
  final _byAddress = <int, NativeExchange>{};
  ExchangeSink? _sink;
  var _closing = false;
  var _closed = false;
  Completer<void>? _drained;

  /// Exchanges taken per poll.
  static const _batchSize = 64;

  /// Polls per wake before yielding to the event loop, so timers and other
  /// I/O get a turn while requests keep coming.
  static const _batchesPerTurn = 4;

  /// The most bytes a WebSocket message from a peer may have.
  final int _maxWebSocketMessage;

  NativeAdapter._(
    this._server,
    this._reactor,
    this._wake,
    this.address,
    this._maxWebSocketMessage,
  ) : _port = native.serverPort(_server),
      _slot = native.reactorSlot(_reactor),
      _scheme = native.serverSecure(_server) ? 'https' : 'http',
      _authority = _listenerAuthority(address, native.serverPort(_server));

  /// The scheme of a request whose target names none.
  final String _scheme;

  /// The authority of a request without a Host, which HTTP/1.0 allows. It
  /// is the listener itself, bracketed when IPv6.
  final String _authority;

  static String _listenerAuthority(io.InternetAddress address, int port) =>
      Host(address.address, port).encode();

  /// Binds a server on [address] and [port], or joins the one another
  /// isolate created for [group].
  ///
  /// The adapter's reactor runs on this isolate's thread, in ticks the
  /// adapter drives from its event loop. [options] are the server's
  /// limits, see [NativeOptions]. With [tls] the server speaks HTTPS, see
  /// [NativeTls]. An isolate that joins a group gets the server as the
  /// first bind made it, and must pass [tls] as that bind did.
  ///
  /// Throws [UnsupportedError] on a platform without the native library,
  /// [io.TlsException] when [tls] cannot be used, [io.SocketException]
  /// when the port cannot be bound, and [StateError] when the joined
  /// server differs from [tls] in speaking HTTPS.
  static Future<NativeAdapter> bind(
    io.InternetAddress address, {
    int port = 0,
    String? group,
    NativeOptions options = const NativeOptions(),
    NativeTls? tls,
  }) async {
    _initDartApi();
    final nativeOptions = calloc<native.Options>();
    final ip = address.address.toNativeUtf8();
    final groupText = group?.toNativeUtf8() ?? nullptr;
    final pem = tls == null ? nullptr : calloc<native.TlsPem>();
    final chain = _nativeCopy(tls?.certificateChain);
    final key = _nativeCopy(tls?.privateKey);
    final failure = calloc<Uint8>();
    final Pointer<Void> server;
    final _BindFailure why;
    try {
      if (tls != null) {
        pem.ref
          ..certificateChain = chain
          ..certificateChainLen = tls.certificateChain.length
          ..privateKey = key
          ..privateKeyLen = tls.privateKey.length;
      }
      nativeOptions.ref
        ..reactorCapacity = options.reactorCapacity
        ..backlog = options.backlog
        ..maxConnections = options.maxConnections
        ..maxInlineBody = options.maxInlineBody
        ..idleTimeoutMs = options.idleTimeout.inMilliseconds
        ..headerTimeoutMs = options.headerTimeout.inMilliseconds
        ..bodyTimeoutMs = options.bodyTimeout.inMilliseconds
        ..writeTimeoutMs = options.writeTimeout.inMilliseconds;
      server = native.serverBind(
        groupText.cast(),
        ip.cast(),
        port,
        nativeOptions,
        pem,
        failure,
      );
      why = _BindFailure.values[failure.value];
    } finally {
      calloc.free(nativeOptions);
      calloc.free(ip);
      if (groupText != nullptr) calloc.free(groupText);
      if (pem != nullptr) calloc.free(pem);
      if (chain != nullptr) calloc.free(chain);
      if (key != nullptr) calloc.free(key);
      calloc.free(failure);
    }
    if (server == nullptr) {
      throw switch (why) {
        _BindFailure.certificateChain => const io.TlsException(
          'relic_native: the certificate chain has no certificate, or one '
          'that is expired, unreadable or repeats a subject',
        ),
        _BindFailure.privateKey => const io.TlsException(
          'relic_native: the private key is not an unencrypted PKCS#8 or '
          'SEC 1 key of a kind tls.zig signs with',
        ),
        _BindFailure.none || _BindFailure.bind => io.SocketException(
          'relic_native could not bind',
          address: address,
          port: port,
        ),
      };
    }
    if (native.serverSecure(server) != (tls != null)) {
      throw StateError(
        'relic_native: the server for group "$group" was bound '
        '${tls == null ? 'with' : 'without'} TLS',
      );
    }
    final wake = RawReceivePort(null, 'relic_native');
    final reactor = native.reactorCreate(server, wake.sendPort.nativePort);
    if (reactor == nullptr) {
      wake.close();
      throw StateError(
        'relic_native: every reactor slot of the server for group "$group" '
        'is taken (reactorCapacity: ${options.reactorCapacity})',
      );
    }
    return NativeAdapter._(
      server,
      reactor,
      wake,
      address,
      options.maxWebSocketMessage,
    );
  }

  /// [bytes] in native memory the caller frees, or null for null. Never
  /// null for an empty list, since the native side takes a non-null
  /// pointer with the length.
  static Pointer<Uint8> _nativeCopy(List<int>? bytes) {
    if (bytes == null) return nullptr;
    final copy = calloc<Uint8>(max(bytes.length, 1));
    copy.asTypedList(bytes.length).setAll(0, bytes);
    return copy;
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
      const AdapterCapabilities(hijack: true, webSocket: true);

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
    // 0 comes from the waiter thread when the loop has events or a timer
    // is due. 1 comes from this isolate, a drain it scheduled on itself.
    // A raw port's handler runs in whatever zone is current when the
    // message lands, so bind it to the zone that started the server. That
    // is where handlers expect to run, as with dart:io's listen.
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

  /// Schedules a tick for something handed to the native side that the
  /// reactor acts on at its next pass.
  ///
  /// Called from inside the drain, as by a sync handler answering, the
  /// drain takes it on its next batch. From anywhere else it is a turn of
  /// the event loop away, as a message to this isolate's own port. A zero
  /// Timer would go through the dart:io event handler thread and back,
  /// 10 us on that thread per hop. The port message stays in this isolate.
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

  /// Ticks the reactor until it has nothing left, then arms the waiter.
  ///
  /// It hands back to the event loop earlier once a handler has an answer
  /// pending, or after a few batches, so timers and the handlers' own I/O
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
        if (_handOver(n, sink)) handedOver = true;
        if (n > 0 || _drainAgain || native.reactorPending(_reactor)) continue;
        // What this turn handed to Dart may answer from a microtask, an
        // async handler or a stream listener such as the WebSocket framer.
        // Those run when the drain returns, so the turn ends here and the
        // next one picks their writes up. A sync handler has answered
        // already and does not end the turn.
        if (handedOver) break;
        // Nothing to do. One tick that waits in the kernel for a moment
        // catches the next request without a thread handoff, which is what
        // a busy reactor sees next. Only then does the isolate park on the
        // waiter and its port message.
        _drainAgain = false;
        final m = native.reactorTick(
          _reactor,
          _linger.inMilliseconds,
          _out,
          _batchSize,
        );
        if (_handOver(m, sink)) handedOver = true;
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

  /// Hands what a tick produced to Dart, events first, then the [n] new
  /// exchanges. True when a handler is still at work on one of them.
  ///
  /// A frame the tick has freed posts the last event of a connection. A
  /// sync handler of a new exchange may hold that connection as a
  /// WebSocket or a raw channel and write to it. The event moves the
  /// connection on first, so the write finds it gone and not the frame.
  ///
  /// An event for an exchange of this same tick finds no listing yet and
  /// is dropped. The body stream pulls what is queued when it is listened
  /// to, and every later chunk posts an event of its own.
  bool _handOver(int n, ExchangeSink sink) {
    final events = _dispatchEvents();
    final exchanges = _takeExchanges(n, sink);
    return events || exchanges;
  }

  /// Hands [n] new exchanges to [sink]. True when an async handler is
  /// still at work on one of them.
  bool _takeExchanges(int n, ExchangeSink sink) {
    var async = false;
    for (var i = 0; i < n; i++) {
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

  /// Hands the events the native side posted to their exchanges. True when
  /// there was at least one.
  ///
  /// An event is the address of a view, with the low bit set for the last
  /// event of a raw connection, whose view is about to die.
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
  }

  /// Completes a close-path waiter the first time its set empties. A
  /// connection that ends later, while the close aborts the rest, finds
  /// it completed.
  static void _settle(Completer<void>? waiter) {
    if (waiter != null && !waiter.isCompleted) waiter.complete();
  }

  /// Records that [exchange] became a raw channel. The drain no longer
  /// waits for it, and the close path takes it down with the other
  /// connections.
  void _tookOver(NativeExchange exchange) {
    _inFlight.remove(exchange);
    _hijacked.add(exchange);
    if (_inFlight.isEmpty) _settle(_drained);
  }

  @override
  Future<void> close({bool force = false}) async {
    if (!_closing) {
      _closing = true;
      // The stop goes first, so the rest of a drain turn accepts nothing.
      native.reactorStop(_reactor);
      if (_inDrain) {
        // A handler is closing its own server. The drain's batch still
        // reads the buffers that a forced close frees below.
        final returned = _drainReturned = Completer<void>();
        await returned.future;
      }
      // The idle connections unwind on a tick.
      _scheduleDrain();
    }
    if (!force) {
      if (_inFlight.isNotEmpty) await (_drained ??= Completer<void>()).future;
      return;
    }
    if (_closed) return _closedFuture.future;
    _closed = true;
    for (final exchange in _inFlight.toList()) {
      exchange.abort();
    }
    for (final exchange in _hijacked.toList()) {
      exchange.abort();
    }
    _wake.close();
    // Blocks while the connections unwind.
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

/// The stage of an exchange between its request and the native side
/// freeing it.
///
/// Every stage but [ended] has a live view.
enum _Stage {
  /// Not answered yet.
  pending,

  /// The head went out and the body streams from Dart.
  streaming,

  /// A raw channel after [NativeExchange.hijack].
  raw,

  /// The raw channel's sink was closed and the native side flushes.
  /// Nothing is read from the view until its last event.
  rawClosing,

  /// A WebSocket after [NativeExchange.upgradeWebSocket].
  webSocket,

  /// Answered, aborted or gone. The view is null.
  ended,
}

/// One request received by the native side and the response that goes back.
///
/// The constructor copies everything the request side needs out of native
/// memory, so the [Request] built from it is plain Dart data with no
/// lifetime tied to the connection. A streamed body is the exception. Its
/// chunks are pulled while the handler runs.
final class NativeExchange extends LinkedListEntry<NativeExchange>
    with ExchangeEndState
    implements AdapterExchange {
  final NativeAdapter _adapter;

  /// The native view, null once the native side has freed the exchange or
  /// is about to, which is [_Stage.ended].
  Pointer<native.ExchangeView>? _view;
  final int _address;
  var _stage = _Stage.pending;

  _RawSink? _rawSink;

  /// The request body handed to the handler, to tell whether it read it.
  Body? _bodyObject;

  NativeWebSocket? _webSocket;

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

  /// The inbound body stream, while a streamed request body is being
  /// pulled.
  StreamController<Uint8List>? _inbound;

  /// Whether the streamed request body was pulled to its end.
  var _bodyRead = false;

  /// The outbound body subscription, while a streamed response goes out.
  StreamSubscription<Uint8List>? _outbound;
  var _outSent = 0;

  /// The outbound chunks handed over and not yet written at which the
  /// stream pauses until the native side catches up.
  static const _outWindow = 8;

  static final _noBytes = Uint8List(0);

  NativeExchange._(NativeAdapter adapter, Pointer<native.ExchangeView> view)
    : this._from(adapter, view, view.ref);

  /// Reads the view once, since every `ref` builds a struct view of its own.
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
  Request toRequest(RequestFactory create) {
    final headers = Headers.fromStore(ByteHeaderStore(_head, _slots));
    final (target, scheme, authority) = _parseTarget();
    return create(
      method,
      this,
      target: target..validate(),
      authority:
          authority ?? headers.value(HeaderName.host) ?? _adapter._authority,
      scheme: scheme ?? _adapter._scheme,
      headers: headers,
      body: _bodyObject = Body.of(
        headers.tryGet(Headers.contentType),
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
  /// the scheme and authority an absolute-form target carries.
  ///
  /// An origin server uses those over the Host header (RFC 9112 3.2.2).
  /// The fragment and decoding checks are the target's own. The asterisk
  /// and authority forms are not served. They throw, and the core answers
  /// 400, as the dart:io adapter does.
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
    if (controller == null || controller.isClosed) return;
    final view = _stage == _Stage.webSocket ? null : _view;
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

  /// Sends [response]. One to an exchange the adapter already aborted, or
  /// whose peer hung up, goes nowhere without error, since the handler
  /// could not know. A second response to an answered exchange throws.
  @override
  FutureOr<void> respond(Response response) {
    if (_stage != _Stage.pending) {
      if (end == ExchangeEnd.aborted || end == ExchangeEnd.cancelledByPeer) {
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

  void _write(Response response, ResponseFraming framing, Uint8List bytes) {
    final head = ResponseHead(response, framing);
    if (_writeInline(head, framing, bytes)) return;
    final (headBuffer, headLength) = _nativeHead(head);
    final view = _takeView(_Stage.ended);
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
  /// on the wire when the length is unknown.
  ///
  /// Completes when the last chunk was handed over. Fails when the body
  /// stream failed, and the connection drops then, since the message
  /// cannot be finished.
  Future<void> _stream(Response response, ResponseFraming framing) {
    final body = response.body;
    // Read before the head goes out. A body that was already read throws
    // here, while the exchange is still open for the 500.
    final chunks = body.read();
    // The view is taken last. A head that does not encode leaves the
    // exchange open for the 500 the core sends next.
    final (headBuffer, headLength) = _nativeHead(
      ResponseHead(response, framing),
    );
    final view = _takeView(_Stage.streaming);
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

  /// The future [respond] returned for a streamed response, while the
  /// stream is being written.
  Completer<void>? _streamDone;

  /// Ends a streamed response that cannot be finished. The native side
  /// drops the connection. The respond that streamed it fails with
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
    final ref = pending.ref;
    final scratch = ref.scratch;
    final capacity = ref.scratchCap;
    if (scratch == nullptr || head.bound + bytes.length > capacity) {
      return false;
    }
    final out = scratch.asTypedList(capacity);
    final headLength = head.writeTo(out);
    out.setRange(headLength, headLength + bytes.length, bytes);
    native.respondInline(
      _takeView(_Stage.ended),
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

  /// Takes the connection over as a raw byte channel.
  ///
  /// Nothing has been written to the peer, so the handler writes the whole
  /// response, or whatever protocol it speaks instead. An inline request
  /// body the handler did not read comes first on the stream, as the
  /// dart:io adapter does it. Closing the sink closes the connection once
  /// what was written is flushed.
  ///
  /// A streamed request body, chunked or over the inline limit, must be
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
    final view = _takeView(_Stage.raw);
    _expectEvents();
    native.hijack(view);
    _adapter._scheduleDrain();
    _adapter._tookOver(this);
    completeEnd(ExchangeEnd.hijacked);
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
    if (_stage != _Stage.raw || data.isEmpty) return;
    final view = _view!;
    final buffer = _nativeCopy(data);
    _adapter._scheduleDrain();
    if (!native.writeChunk(view, buffer, data.length)) {
      native.free(buffer);
      _failRaw(const io.SocketException('relic_native: out of memory'));
    }
  }

  /// Closes the raw channel. The native side writes what is queued, closes
  /// the connection and posts one last event. Reading stops now.
  void _closeRaw() {
    if (_stage != _Stage.raw) return;
    _stage = _Stage.rawClosing;
    native.finishStream(_view!, true);
    _adapter._scheduleDrain();
    final inbound = _inbound;
    if (inbound != null && !inbound.isClosed) unawaited(inbound.close());
  }

  /// Drops a raw connection. The stream ends, with [error] when there is
  /// one, and the native side frees the connection.
  void _failRaw([Object? error]) {
    final stage = _stage;
    if (stage != _Stage.raw && stage != _Stage.rawClosing) return;
    final view = _view!;
    _release();
    if (stage == _Stage.raw) native.abort(view);
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
    _release();
    _rawSink?._ended();
    _adapter._finished(this);
  }

  /// Writes the 101 and leaves the connection with its task, which frames
  /// it from then on.
  @override
  RelicWebSocket upgradeWebSocket(String acceptKey) {
    final head = webSocketHandshakeResponse(acceptKey);
    final view = _takeView(_Stage.webSocket);
    _expectEvents();
    native.wsUpgrade(
      view,
      _nativeCopy(head),
      head.length,
      _adapter._maxWebSocketMessage,
    );
    _adapter._scheduleDrain();
    _adapter._tookOver(this);
    completeEnd(ExchangeEnd.upgraded);
    return _webSocket = NativeWebSocket._(this);
  }

  /// Pongs the native side has counted, or null once the connection is
  /// gone.
  int? get _wsPongs => _stage == _Stage.webSocket ? _view!.ref.wsPongs : null;

  /// Queues a frame for the peer. Nothing happens on a connection that is
  /// gone.
  void _wsSend(WebSocketOpcode opcode, Uint8List payload) {
    if (_stage != _Stage.webSocket) return;
    final view = _view!;
    var buffer = nullptr.cast<Uint8>();
    if (payload.isNotEmpty) buffer = _nativeCopy(payload);
    _adapter._scheduleDrain();
    if (!native.wsSend(view, buffer, payload.length, opcode.code)) {
      if (buffer != nullptr) native.free(buffer);
      // Out of memory.
      abort();
    }
  }

  /// Hands the socket the messages the native side queued.
  void _pullWs() {
    final socket = _webSocket;
    if (_stage != _Stage.webSocket || socket == null) return;
    final view = _view!;
    final data = _adapter._chunkData;
    final length = _adapter._chunkLength;
    final kind = _adapter._chunkStatus;
    try {
      while (native.wsRead(view, data, length, kind) != 0) {
        final pointer = data.value;
        final bytes = pointer == nullptr
            ? _noBytes
            : pointer.asTypedList(length.value);
        try {
          socket._onMessage(_WsKind.of(kind.value), bytes);
        } finally {
          if (pointer != nullptr) native.free(pointer);
        }
      }
    } finally {
      // Credit went back to the reader, which the next tick acts on.
      _adapter._scheduleDrain();
    }
  }

  /// The native side is done with a WebSocket connection.
  void _wsGone() {
    _release();
    _webSocket?._gone();
    _adapter._finished(this);
  }

  @override
  void abort() {
    switch (_stage) {
      case _Stage.pending:
        final view = _takeView(_Stage.ended);
        native.abort(view);
        _adapter._scheduleDrain();
        _finish(ExchangeEnd.aborted);
      case _Stage.streaming:
        // The head went out. The body cannot be finished, so the last
        // chunk says so and the connection drops.
        if (_outbound != null) _failStream(_view!);
      case _Stage.raw || _Stage.rawClosing:
        _failRaw();
      case _Stage.webSocket:
        final view = _view!;
        _release();
        native.abort(view);
        _adapter._scheduleDrain();
        _webSocket?._gone();
        _adapter._finished(this);
      case _Stage.ended:
        break;
    }
  }

  var _expectsEvents = false;

  /// Lists the exchange for the events the native side posts about it.
  ///
  /// It posts them for a streamed request body, a watched peer, a
  /// streamed response, a hijacked connection and a WebSocket, so an
  /// exchange is listed before any of those starts. One answered from
  /// memory is never listed.
  void _expectEvents() {
    if (_expectsEvents) return;
    _expectsEvents = true;
    _adapter._byAddress[_address] = this;
  }

  /// Takes the native view and moves the exchange from [_Stage.pending]
  /// to [next].
  ///
  /// The native side frees the exchange after respond or abort, so a
  /// second take would touch a dead frame and throws instead.
  Pointer<native.ExchangeView> _takeView(_Stage next) {
    final view = _view;
    if (view == null || _stage != _Stage.pending) {
      throw StateError('The exchange was already answered');
    }
    _stage = next;
    if (next == _Stage.ended) _view = null;
    return view;
  }

  /// The native side has freed the exchange, or will on the next tick.
  void _release() {
    _stage = _Stage.ended;
    _view = null;
  }

  /// A future that completes when the peer hangs up before the response.
  ///
  /// The first read asks the native side to watch the connection, so only
  /// handlers that want to know pay for it.
  @override
  Future<void> get cancelled {
    final cancelled = _cancelled;
    if (cancelled != null) return cancelled.future;
    final created = _cancelled = Completer<void>();
    if (_stage == _Stage.pending) {
      _expectEvents();
      native.watch(_view!);
    }
    return created.future;
  }

  /// Handles an event about this exchange from the native side while it is
  /// in flight. A frame about to die posts the [last] one of a raw
  /// connection, so that one does not read the view.
  void _onEvent({required bool last}) {
    if (last) {
      switch (_stage) {
        case _Stage.raw || _Stage.rawClosing:
          _rawGone();
        case _Stage.webSocket:
          _wsGone();
        case _Stage.pending || _Stage.streaming || _Stage.ended:
          break;
      }
      return;
    }
    switch (_stage) {
      case _Stage.webSocket:
        _pullWs();
        return;
      case _Stage.rawClosing || _Stage.ended:
        // After the sink closed, what the peer still sends or its EOF is
        // of no interest, and the view is read only up to the last event.
        return;
      case _Stage.pending || _Stage.streaming || _Stage.raw:
        break;
    }
    final view = _view!;
    final ref = view.ref;
    final writeFailed = ref.writeFailed != 0;
    if (_stage == _Stage.raw && writeFailed) {
      _failRaw(const io.SocketException('The peer stopped reading'));
      return;
    }
    // A failed write is the peer gone while the response streams, which
    // is the only way the task sees it then, as with dart:io.
    if (ref.peerGone != 0 || writeFailed) {
      final cancelled = _cancelled;
      if (cancelled != null && !cancelled.isCompleted) cancelled.complete();
    }
    if (_inbound != null) _pullInbound();
    final outbound = _outbound;
    if (outbound != null) {
      if (writeFailed) {
        _failStream(view);
      } else if (outbound.isPaused &&
          _outSent - ref.chunksWritten < _outWindow) {
        outbound.resume();
      }
    }
  }

  void _finish(ExchangeEnd end) {
    completeEnd(end);
    _release();
    final inbound = _inbound;
    if (inbound != null && !inbound.isClosed) unawaited(inbound.close());
    _adapter._finished(this);
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
