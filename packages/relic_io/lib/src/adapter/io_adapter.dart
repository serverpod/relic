import 'dart:async';
import 'dart:io' as io;
import 'dart:typed_data';

import 'package:stream_channel/stream_channel.dart';

import 'package:relic_core/relic_core.dart';
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
  /// exist. They are tracked here so shutdown can close them and
  /// [connectionsInfo] can report them.
  final _hijackedSockets = <io.Socket>{};
  final _webSockets = <IORelicWebSocket>{};

  /// How long a graceful shutdown waits for a detached connection to finish
  /// on its own before it is closed anyway.
  ///
  /// Without a ceiling a peer that never answers would keep the shutdown
  /// pending forever.
  static const _drainTimeout = Duration(seconds: 5);

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
      final pending = sink(IOExchange._(this, request));
      // The sink never fails by contract. An error here is a bug in the
      // core, and the zone around `start` reports it.
      if (pending is Future<void>) unawaited(pending);
    });
  }

  @override
  Future<void> close({bool force = false}) async {
    if (force) {
      await _server.close(force: true);
      _destroyDetached();
      return;
    }
    await _server.close();
    await _closeDetached().timeout(_drainTimeout, onTimeout: _destroyDetached);
    _destroyDetached();
  }

  /// Asks every detached connection to close, telling WebSocket peers that
  /// the server is going away (RFC 6455 1001).
  ///
  /// The tracking sets are deliberately left alone: a hijacked socket removes
  /// itself when it completes, so whatever is still tracked when the drain
  /// deadline passes is exactly what [_destroyDetached] must drop.
  Future<void> _closeDetached() async {
    await Future.wait([
      for (final ws in _webSockets.toList()) ws.closeGoingAway(),
      for (final socket in _hijackedSockets.toList()) socket.close(),
    ], eagerError: false).catchError((_) => const <Object?>[]);
  }

  /// Drops whatever is left without waiting for the peer.
  ///
  /// Hijacked sockets are destroyed outright. WebSockets get a fire-and-forget
  /// [IORelicWebSocket.closeGoingAway] instead: `dart:io` exposes no hard
  /// teardown for an upgraded socket, but bounds internally how long a peer
  /// can stall the close handshake.
  void _destroyDetached() {
    for (final socket in _hijackedSockets.toList()) {
      socket.destroy();
    }
    _hijackedSockets.clear();
    for (final ws in _webSockets.toList()) {
      unawaited(ws.closeGoingAway());
    }
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
    _webSockets
      ..removeWhere((ws) => ws.isClosed)
      ..add(webSocket);
  }
}

/// One `dart:io` request and its response.
final class IOExchange implements AdapterExchange {
  final IOAdapter _adapter;
  final io.HttpRequest _request;
  final _done = Completer<ExchangeEnd>();
  final _cancelled = Completer<void>();

  IOExchange._(this._adapter, this._request) {
    // dart:io reports a peer that went away as an error on `done`. That is
    // its only signal, and it fires only once something was written, so
    // `cancelled` is best effort on this adapter.
    _request.response.done.then(
      (_) {},
      onError: (Object _) {
        if (!_cancelled.isCompleted) _cancelled.complete();
        _finish(ExchangeEnd.cancelledByPeer);
      },
    );
  }

  @override
  HttpProtocol get protocol => switch (_request.protocolVersion) {
    '1.0' => HttpProtocol.http10,
    _ => HttpProtocol.http11,
  };

  @override
  Request toRequest() => fromHttpRequest(_request);

  @override
  Future<void> respond(Response response) async {
    try {
      await response.writeHttpResponse(_request.response);
      _finish(ExchangeEnd.completed);
    } catch (_) {
      _finish(ExchangeEnd.aborted);
      rethrow;
    }
  }

  @override
  Future<StreamChannel<Uint8List>> hijack() async {
    final socket = await _request.response.detachSocket(writeHeaders: false);
    _adapter._trackHijacked(socket);
    _finish(ExchangeEnd.hijacked);
    return StreamChannel<Uint8List>(socket, _SocketSink(socket));
  }

  @override
  Future<RelicWebSocket> upgradeWebSocket() async {
    final webSocket = await IORelicWebSocket.fromHttpRequest(_request);
    _adapter._trackWebSocket(webSocket);
    _finish(ExchangeEnd.upgraded);
    return webSocket;
  }

  @override
  void abort() {
    if (_done.isCompleted) return;
    _finish(ExchangeEnd.aborted);
    unawaited(
      _request.response
          .detachSocket(writeHeaders: false)
          .then((socket) => socket.destroy())
          .catchError((_) => _request.response.close())
          .catchError((_) {}),
    );
  }

  @override
  Future<void> get cancelled => _cancelled.future;

  @override
  Future<ExchangeEnd> get done => _done.future;

  void _finish(ExchangeEnd end) {
    if (!_done.isCompleted) _done.complete(end);
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
