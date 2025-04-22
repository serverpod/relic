import 'dart:async';
import 'dart:io' as io;

import '../../../relic.dart';
import 'io_adaptors.dart';
import 'request.dart';
import 'response.dart';

class _IORequestContext implements RequestContext {
  final io.HttpRequest _ioRequest;

  _IORequestContext(this._ioRequest);

  /// Important this is late, so that potential exceptions are raised
  /// when consumer reads, as opposed to when the request is created.
  @override
  late Request request = fromHttpRequest(_ioRequest);

  @override
  Future<void> respond(final Response response) async {
    await response.writeHttpResponse(_ioRequest.response);
  }
}

/// IO-specific implementation of ServerAdaptor using dart:io's HttpServer
class IOAdaptor implements Adaptor {
  final io.HttpServer _server;

  /// Creates a new IOServerAdaptor wrapping the given HttpServer
  IOAdaptor(this._server);

  @override
  late Stream<RequestContext> requests = _server.map(_IORequestContext.new);

  @override
  Address get address => _server.address.toAddressType();

  @override
  int get port => _server.port;
}
