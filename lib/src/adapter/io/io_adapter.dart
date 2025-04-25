import 'dart:async';
import 'dart:io' as io;

import 'package:stream_channel/stream_channel.dart';

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
    final httpResponse = (request as _IOAdapterRequest)._httpRequest.response;
    await response.writeHttpResponse(httpResponse);
  }

  @override
  Future<void> hijack(
    final AdapterRequest request,
    final HijackCallback callback,
  ) async {
    final socket = await (request as _IOAdapterRequest)
        ._httpRequest
        .response
        .detachSocket(writeHeaders: false);
    callback(StreamChannel(socket, socket));
  }

  @override
  Future<void> close() => _server.close(force: true);
}

class _IOAdapterRequest extends AdapterRequest {
  final io.HttpRequest _httpRequest;
  _IOAdapterRequest(this._httpRequest);

  @override
  Request toRequest() => fromHttpRequest(_httpRequest);
}
