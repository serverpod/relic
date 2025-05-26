import 'dart:async';
import 'dart:io' as io;
import 'dart:typed_data';

import 'package:stream_channel/stream_channel.dart';
import 'package:web_socket/io_web_socket.dart';
import 'package:web_socket_channel/adapter_web_socket_channel.dart';

import '../../../relic.dart';
import 'request.dart';
import 'response.dart';

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
  Stream<AdapterRequest> get requests => _server.map(_IOAdapterRequest.new);

  @override
  Future<void> respond(
    final AdapterRequest request,
    final Response response,
  ) async {
    if (request is! _IOAdapterRequest) _fatal();
    final httpResponse = request._httpRequest.response;
    await response.writeHttpResponse(httpResponse);
  }

  @override
  Future<void> hijack(
    final AdapterRequest request,
    final HijackCallback callback,
  ) async {
    if (request is! _IOAdapterRequest) _fatal();
    final socket =
        await request._httpRequest.response.detachSocket(writeHeaders: false);
    callback(StreamChannel(socket, socket));
  }

  @override
  Future<void> connect(
    final AdapterRequest request,
    final DuplexStreamCallback callback,
  ) async {
    if (request is! _IOAdapterRequest) _fatal();
    final webSocket =
        await io.WebSocketTransformer.upgrade(request._httpRequest);
    webSocket.pingInterval = const Duration(seconds: 15);
    final channel =
        AdapterWebSocketChannel(IOWebSocket.fromWebSocket(webSocket));
    callback(DuplexStreamChannel(
      channel.stream.map(_encode),
      channel.sink.mapFrom(_decode),
    ));
  }

  @override
  Future<void> close() => _server.close(force: true);
}

Never _fatal() =>
    throw StateError('Fatal: Unexpected request type for IOAdapter.');

class _IOAdapterRequest extends AdapterRequest {
  final io.HttpRequest _httpRequest;
  _IOAdapterRequest(this._httpRequest);

  @override
  Request toRequest() => fromHttpRequest(_httpRequest);
}

Payload _encode(final dynamic decoded) {
  return switch (decoded) {
    final String s => TextPayload(s),
    final Uint8List b => BinaryPayload(b),
    _ => throw UnsupportedError(
        '${decoded.runtimeType} must be either String or Uint8List'),
  };
}

dynamic _decode(final Payload payload) {
  return switch (payload) {
    BinaryPayload() => payload.data,
    TextPayload() => payload.data,
  };
}

extension<T> on Sink<T> {
  /// Creates a new [StreamSink<R>] that maps its incoming values of type [R]
  /// to type [T] using the provided [mapper] function, and then adds them
  /// to this sink.
  StreamSink<R> mapFrom<R>(final T Function(R) mapper) {
    final controller = StreamController<R>();
    controller.stream.map(mapper).listen(add);
    return controller.sink;
  }
}
