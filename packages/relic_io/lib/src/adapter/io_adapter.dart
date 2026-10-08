import 'dart:async';
import 'dart:io' as io;
import 'dart:typed_data';

import 'package:relic_core/relic_core.dart';
import 'package:stream_channel/stream_channel.dart';

import 'bind_http_server.dart';
import 'io_relic_web_socket.dart';
import 'request.dart';
import 'response.dart';

/// An [Adapter] implementation for `dart:io` [HttpServer].
///
/// This adapter bridges Relic with a standard Dart HTTP server, allowing
/// Relic applications to handle HTTP requests and responses, as well as
/// WebSocket connections.
class IOAdapter implements Adapter {
  final io.HttpServer _server;
  StreamSubscription<io.HttpRequest>? _subscription;

  /// Connections that have been detached from [_server].
  ///
  /// Hijacking and upgrading both take the connection out of the underlying
  /// server's bookkeeping, so from that point on nothing else knows they
  /// exist. This set lets a forced close drop the hijacked ones and lets
  /// [connectionsInfo] report both kinds.
  final _hijackedSockets = <io.Socket>{};
  final _webSockets = <IORelicWebSocket>{};

  /// Exchanges handed to the sink that have not ended.
  ///
  /// dart:io's own close does not wait for them.
  var _inFlight = 0;
  Completer<void>? _drained;

  /// Creates an [IOAdapter] that wraps the provided [io.HttpServer].
  ///
  /// The adapter listens for requests from [_server] once [start] is
  /// called.
  IOAdapter(this._server);

  /// Binds an HTTP server to the given [address] and [port].
  ///
  /// If [context] is provided, a secure HTTPS server will be started using
  /// [io.HttpServer.bindSecure]. Otherwise, an HTTP server will be started
  /// using [io.HttpServer.bind].
  ///
  /// - [address]: The [io.InternetAddress] to bind the server to.
  /// - [port]: The port number to listen on. Defaults to 0, which means
  ///   the operating system will assign an available port.
  /// - [context]: An optional [io.SecurityContext] for HTTPS. If null, HTTP is used.
  /// - [backlog]: The maximum length of the queue for incoming connections.
  ///   Defaults to 0 (system-dependent).
  /// - [v6Only]: Whether to only accept IPv6 connections. This is only
  ///   meaningful for IPv6 addresses. Defaults to false.
  /// - [shared]: Whether to allow multiple `HttpServer` objects to bind to the
  ///   same combination of [address], [port] and [v6Only]. Defaults to false.
  ///
  /// Returns a [Future] that completes with the bound [io.HttpServer].
  static Future<IOAdapter> bind(
    io.InternetAddress address, {
    int port = 0,
    io.SecurityContext? context,
    int backlog = 0,
    bool v6Only = false,
    bool shared = false,
  }) async {
    return IOAdapter(
      await bindHttpServer(
        address,
        port: port,
        context: context,
        backlog: backlog,
        v6Only: v6Only,
        shared: shared,
      ),
    );
  }

  /// The [io.InternetAddress] the underlying server is listening on.
  io.InternetAddress get address => _server.address;

  @override
  AdapterCapabilities get capabilities =>
      const AdapterCapabilities(hijack: true, webSocket: true);

  @override
  List<Listener> get listeners => [
    Listener(Transport.tcp, _server.address.address, _server.port, const {
      HttpProtocol.http10,
      HttpProtocol.http11,
    }),
  ];

  @override
  void start(ExchangeSink sink) {
    if (_subscription != null) throw StateError('start was already called');
    _subscription = _server.listen((request) {
      _inFlight++;
      final pending = sink(IOExchange._(this, request));
      // The sink never fails by contract. An error here is a bug in the
      // core, and the zone around `start` reports it.
      if (pending is Future<void>) unawaited(pending);
    });
  }

  /// Without [force], dart:io stops accepting and closes idle connections.
  ///
  /// The returned future completes once the exchanges in flight have ended.
  /// Detached connections are the server's to close before that.
  @override
  Future<void> close({bool force = false}) async {
    if (force) {
      await _server.close(force: true);
      _destroyDetached();
      return;
    }
    await _server.close();
    if (_inFlight > 0) await (_drained ??= Completer<void>()).future;
  }

  void _finished() {
    _inFlight--;
    final drained = _drained;
    if (_inFlight == 0 && drained != null && !drained.isCompleted) {
      drained.complete();
    }
  }

  /// Drops whatever is left without waiting for the peer.
  ///
  /// dart:io exposes no hard teardown for an upgraded socket. It does bound
  /// the close handshake the server started itself.
  void _destroyDetached() {
    for (final socket in _hijackedSockets.toList()) {
      socket.destroy();
    }
    _hijackedSockets.clear();
    _webSockets.clear();
  }

  @override
  ConnectionsInfo get connectionsInfo {
    final info = _server.connectionsInfo();
    final detached =
        _hijackedSockets.length +
        _webSockets.where((ws) => !ws.isClosed).length;
    return (
      active: info.active + detached,
      closing: info.closing,
      idle: info.idle,
    );
  }

  void _trackHijacked(io.Socket socket) {
    _hijackedSockets.add(socket);
    unawaited(
      socket.done
          .catchError((_) {})
          .whenComplete(() => _hijackedSockets.remove(socket)),
    );
  }

  void _trackWebSocket(IORelicWebSocket webSocket) {
    _webSockets.add(webSocket);
    unawaited(webSocket.done.whenComplete(() => _webSockets.remove(webSocket)));
  }
}

/// One `dart:io` request and its response.
final class IOExchange with ExchangeEndState implements AdapterExchange {
  final IOAdapter _adapter;
  final io.HttpRequest _request;

  /// The [cancelled] future of a caller that asked before the peer went
  /// away.
  Completer<void>? _cancelled;

  /// The request body handed to the handler, so [hijack] can tell whether
  /// the handler read it.
  Body? _body;

  IOExchange._(this._adapter, this._request) {
    // dart:io reports a peer that went away as an error on `done`. That is
    // its only signal, and it fires only once something was written, so
    // `cancelled` is best effort on this adapter.
    _request.response.done.then(
      (_) {},
      onError: (Object _) => _finish(ExchangeEnd.cancelledByPeer),
    );
  }

  @override
  HttpProtocol get protocol => httpProtocolOf(_request);

  @override
  Request toRequest() {
    final request = fromHttpRequest(_request, this);
    _body = request.body;
    return request;
  }

  /// A write that fails leaves the exchange open.
  ///
  /// The core then answers with an error response, or calls [abort] when
  /// that fails too. Either one ends the exchange.
  @override
  Future<void> respond(Response response) async {
    await response.writeHttpResponse(
      _request.response,
      head: _request.method == 'HEAD',
      protocol: httpProtocolOf(_request),
      keepAlive: _request.persistentConnection,
    );
    _finish(ExchangeEnd.completed);
  }

  /// Refuses a chunked request body that the handler has not read.
  ///
  /// Such a body arrives decoded by dart:io's parser, not as the peer sent
  /// it. A body with a length is the peer's bytes as they are.
  @override
  Future<StreamChannel<Uint8List>> hijack() async {
    final body = _body;
    if (body != null && body.contentLength == null && !body.isRead) {
      throw StateError(
        'The request body is chunked and was not read to its end. '
        'Read it before hijacking the connection',
      );
    }
    final socket = await _request.response.detachSocket(writeHeaders: false);
    _adapter._trackHijacked(socket);
    _finish(ExchangeEnd.hijacked);
    return StreamChannel<Uint8List>(socket, _SocketSink(socket));
  }

  /// dart:io computes the accept key itself, so [acceptKey] goes unused.
  @override
  Future<RelicWebSocket> upgradeWebSocket(String acceptKey) async {
    final webSocket = await IORelicWebSocket.fromHttpRequest(_request);
    _adapter._trackWebSocket(webSocket);
    _finish(ExchangeEnd.upgraded);
    return webSocket;
  }

  @override
  void abort() {
    if (end != null) return;
    _finish(ExchangeEnd.aborted);
    final response = _request.response;
    try {
      unawaited(
        response
            .detachSocket(writeHeaders: false)
            .then((socket) => socket.destroy())
            .catchError((_) {}),
      );
    } on StateError {
      // The head went out, and dart:io will not detach such a response. It
      // does destroy the connection of a response that ends in an error. A
      // body that failed on the socket has already ended it that way.
      try {
        response.addError(const io.SocketException('aborted'));
      } on StateError {
        // The failed body is still bound to the response.
      }
    }
  }

  @override
  Future<void> get cancelled => end == ExchangeEnd.cancelledByPeer
      ? Future.value()
      : (_cancelled ??= Completer<void>()).future;

  void _finish(ExchangeEnd end) {
    if (!completeEnd(end)) return;
    if (end == ExchangeEnd.cancelledByPeer) _cancelled?.complete();
    _adapter._finished();
  }
}

/// The socket's sink, narrowed to [Uint8List].
///
/// `StreamChannel.cast` would pipe a controller into the socket instead,
/// which binds the socket sink to a stream, and a later `socket.close()`
/// from shutdown then throws.
final class _SocketSink implements StreamSink<Uint8List> {
  final io.Socket _socket;

  _SocketSink(this._socket);

  @override
  void add(Uint8List data) => _socket.add(data);

  @override
  void addError(Object error, [StackTrace? stackTrace]) =>
      _socket.addError(error, stackTrace);

  @override
  Future<void> addStream(Stream<Uint8List> stream) => _socket.addStream(stream);

  @override
  Future<void> close() => _socket.close();

  @override
  Future<void> get done => _socket.done;
}
