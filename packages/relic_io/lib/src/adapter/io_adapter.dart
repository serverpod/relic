import 'dart:async';
import 'dart:io' as io;

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
class IOAdapter extends Adapter {
  final io.HttpServer _server;

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
  /// The adapter will listen for incoming requests from the [_server] and
  /// expose them through the [requests] stream.
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
    final io.InternetAddress address, {
    final int port = 0,
    final io.SecurityContext? context,
    final int backlog = 0,
    final bool v6Only = false,
    final bool shared = false,
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
  int get port => _server.port;

  @override
  Stream<AdapterRequest> get requests => _server.map(IOAdapterRequest.new);

  @override
  Future<void> respond(
    covariant final IOAdapterRequest request,
    final Response response,
  ) async {
    final httpResponse = request._httpRequest.response;
    await response.writeHttpResponse(httpResponse);
  }

  @override
  Future<void> hijack(
    covariant final IOAdapterRequest request,
    final HijackCallback callback,
  ) async {
    final socket = await request._httpRequest.response.detachSocket(
      writeHeaders: false,
    );
    _hijackedSockets.add(socket);
    unawaited(
      socket.done
          .catchError((final _) {})
          .whenComplete(() => _hijackedSockets.remove(socket)),
    );
    callback(StreamChannel(socket, socket));
  }

  @override
  Future<void> connect(
    covariant final IOAdapterRequest request,
    final WebSocketCallback callback,
  ) async {
    final webSocket = await IORelicWebSocket.fromHttpRequest(
      request._httpRequest,
    );
    _webSockets
      ..removeWhere((final ws) => ws.isClosed)
      ..add(webSocket);
    callback(webSocket);
  }

  @override
  Future<void> close({final bool force = false}) async {
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
    ], eagerError: false).catchError((final _) => const <Object?>[]);
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
        _webSockets.where((final ws) => !ws.isClosed).length;
    return (
      active: info.active + detached,
      closing: info.closing,
      idle: info.idle,
    );
  }
}

class IOAdapterRequest extends AdapterRequest {
  final io.HttpRequest _httpRequest;
  IOAdapterRequest(this._httpRequest);

  @override
  Request toRequest() => fromHttpRequest(_httpRequest);
}
