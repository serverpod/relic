import 'dart:async';
import 'dart:io' as io;
import 'dart:typed_data';

import 'package:stream_channel/stream_channel.dart';
import 'package:web_socket/io_web_socket.dart';
import 'package:web_socket_channel/adapter_web_socket_channel.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

import '../../../relic.dart';
import '../duplex_stream_channel.dart';
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
    final DuplexStreamCallback callback,
  ) async {
    final webSocket =
        await io.WebSocketTransformer.upgrade(request._httpRequest);
    callback(_IODuplexStreamChannel(webSocket));
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

/// A [DuplexStreamChannel] implementation for `dart:io` [WebSocket]s.
///
/// This class wraps an [io.WebSocket] and provides a standard stream and sink
/// interface for sending and receiving [Payload] messages (binary or text).
class _IODuplexStreamChannel extends DuplexStreamChannel {
  final io.WebSocket _socket;
  final WebSocketChannel _socketChannel;

  _IODuplexStreamChannel(final io.WebSocket socket)
      : _socket = socket,
        _socketChannel =
            AdapterWebSocketChannel(IOWebSocket.fromWebSocket(socket));

  @override
  Duration? get pingInterval => _socket.pingInterval;

  @override
  set pingInterval(final Duration? value) => _socket.pingInterval = value;

  @override
  Future<void> close([final int? closeCode, final String? closeReason]) async {
    // Yield to the event loop to allow pending data to be flushed before closing
    await Future<void>.delayed(const Duration(microseconds: 0));
    await _socket.close(closeCode, closeReason);
  }

  @override
  StreamSink<Payload> get sink => _socketChannel.sink.mapFrom(_decode);

  @override
  Stream<Payload> get stream => _socketChannel.stream.map(_encode);

  /// Encodes a raw WebSocket message (String or Uint8List) into a [Payload].
  static Payload _encode(final dynamic decoded) {
    return switch (decoded) {
      final String s => TextPayload(s),
      final Uint8List b => BinaryPayload(b),
      _ => throw UnsupportedError(
          '${decoded.runtimeType} must be either String or Uint8List'),
    };
  }

  /// Decodes a [Payload] into a raw WebSocket message (String or Uint8List).
  static dynamic _decode(final Payload payload) {
    return switch (payload) {
      BinaryPayload() => payload.data,
      TextPayload() => payload.data,
    };
  }
}

extension<T> on EventSink<T> {
  /// Creates a new [StreamSink<R>] that maps its incoming values of type [R]
  /// to type [T] using the provided [mapper] function, and then adds them
  /// to this sink.
  StreamSink<R> mapFrom<R>(final T Function(R) mapper) {
    final controller = StreamController<R>();
    controller.stream.map(mapper).listen(
          add,
          onError: addError,
          onDone: close,
        );
    return controller.sink;
  }
}
