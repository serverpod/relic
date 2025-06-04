import 'dart:async';
import 'dart:io' as io;
import 'dart:typed_data';

import 'package:stream_channel/stream_channel.dart';
import 'package:web_socket/io_web_socket.dart';
import 'package:web_socket/web_socket.dart';

import '../../../relic.dart';
import '../relic_web_socket.dart';
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

  /// The [io.InternetAddress] the underlying server is listening on.
  io.InternetAddress get address => _server.address;

  /// The port number the underlying server is listening on.
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
    final socket =
        await request._httpRequest.response.detachSocket(writeHeaders: false);
    callback(StreamChannel(socket, socket));
  }

  @override
  Future<void> connect(
    covariant final IOAdapterRequest request,
    final WebSocketCallback callback,
  ) async {
    final webSocket =
        await io.WebSocketTransformer.upgrade(request._httpRequest);
    callback(_IORelicWebSocket(webSocket));
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

/// A [RelicWebSocket] implementation for `dart:io` [io.WebSocket]s.
///
/// This class wraps an [io.WebSocket] and provides a [WebSocket]]
/// interface for sending and receiving events (binary or text).
class _IORelicWebSocket implements RelicWebSocket {
  final io.WebSocket _wrappedSocket;
  final IOWebSocket _socket;

  _IORelicWebSocket(final io.WebSocket socket)
      : _wrappedSocket = socket,
        _socket = IOWebSocket.fromWebSocket(socket);

  @override
  Duration? get pingInterval => _wrappedSocket.pingInterval;

  @override
  set pingInterval(final Duration? value) =>
      _wrappedSocket.pingInterval = value;

  @override
  Future<void> close([final int? code, final String? reason]) =>
      _socket.close(code, reason);

  @override
  Stream<WebSocketEvent> get events => _socket.events;

  @override
  String get protocol => _socket.protocol;

  @override
  void sendBytes(final Uint8List b) => _socket.sendBytes(b);

  @override
  void sendText(final String s) => _socket.sendText(s);
}
