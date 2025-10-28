import 'dart:async';
import 'dart:io' as io;

import 'package:stream_channel/stream_channel.dart';

import '../../../relic.dart';
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
    callback(StreamChannel(socket, socket));
  }

  @override
  Future<void> connect(
    covariant final IOAdapterRequest request,
    final WebSocketCallback callback,
  ) async {
    callback(await IORelicWebSocket.fromHttpRequest(request._httpRequest));
  }

  @override
  Future<void> close() => _server.close(force: true);
}

class IOAdapterRequest extends AdapterRequest {
  final io.HttpRequest _httpRequest;
  IOAdapterRequest(this._httpRequest);

  @override
  Request toRequest() => fromHttpRequest(_httpRequest);
}
