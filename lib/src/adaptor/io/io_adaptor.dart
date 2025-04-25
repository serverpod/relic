import 'dart:async';
import 'dart:io' as io;

import 'package:stream_channel/stream_channel.dart';

import '../../../relic.dart';
import '../../hijack/hijack.dart';
import 'request.dart';
import 'response.dart';

class IOAdaptor extends Adaptor {
  final io.HttpServer _server;

  /// Creates an [IOAdaptor] that wraps the provided [io.HttpServer].
  ///
  /// The adaptor will listen for incoming requests from the [_server] and
  /// expose them through the [requests] stream.
  IOAdaptor(this._server);

  /// The [io.InternetAddress] the underlying server is listening on.
  io.InternetAddress get address => _server.address;

  /// The port number the underlying server is listening on.
  int get port => _server.port;
  @override
  Stream<AdaptorRequest> get requests => _server.map(_IOAdaptorRequest.new);

  @override
  Future<void> respond(
    final AdaptorRequest request,
    final Response response,
  ) async {
    final httpResponse = (request as _IOAdaptorRequest)._httpRequest.response;
    await response.writeHttpResponse(httpResponse);
  }

  @override
  Future<void> hijack(
    final AdaptorRequest request,
    final HijackCallback callback,
  ) async {
    final socket = await (request as _IOAdaptorRequest)
        ._httpRequest
        .response
        .detachSocket(writeHeaders: false);
    callback(StreamChannel(socket, socket));
  }

  @override
  Future<void> close() => _server.close(force: true);
}

class _IOAdaptorRequest extends AdaptorRequest {
  final io.HttpRequest _httpRequest;
  _IOAdaptorRequest(this._httpRequest);

  @override
  Request toRequest() => fromHttpRequest(_httpRequest);
}
