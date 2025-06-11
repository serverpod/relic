import 'dart:async';
import 'dart:io' as io;

import 'package:stream_channel/stream_channel.dart';

import '../../../relic.dart';
import '../context.dart';
import '../ip_address.dart';
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

  @override
  late final IPAddress address =
      IPAddress.fromBytes(_server.address.rawAddress);

  @override
  late final int port = _server.port;

  @override
  Stream<AdapterRequest> get requests => _server.map(IOAdapterRequest.new);

  @override
  NewContext convert(covariant final IOAdapterRequest request) {
    final httpRequest = request._httpRequest;
    return buildNewContext(fromHttpRequest(httpRequest),
        connectionInfoFromHttpRequest(httpRequest));
  }

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
    callback(await IORelicWebSocket.fromHttpRequest(request._httpRequest));
  }

  @override
  Future<void> close() => _server.close(force: true);
}

class IOAdapterRequest implements AdapterRequest {
  final io.HttpRequest _httpRequest;
  IOAdapterRequest(this._httpRequest);
}
