import 'dart:io' as io;

import 'package:relic_core/relic_core.dart';

/// Creates a new [Request] from an [io.HttpRequest], on [exchange].
///
/// Throws [FormatException] for a target that does not decode. The core
/// answers that with 400 before any handler runs.
Request fromHttpRequest(io.HttpRequest request, AdapterExchange exchange) {
  final url = request.requestedUri;
  final target = RequestTarget.fromUri(url)..validate();
  final headers = headersFromHttpRequest(request);
  return RequestInternal.create(
    Method.parse(request.method),
    url,
    exchange,
    target: target,
    protocol: httpProtocolOf(request),
    headers: headers,
    body: bodyFromHttpRequest(request, headers),
    lazyConnectionInfo: () =>
        connectionInfoFromHttpConnectionInfo(request.connectionInfo),
  );
}

/// The HTTP version [request] arrived with.
HttpProtocol httpProtocolOf(io.HttpRequest request) =>
    switch (request.protocolVersion) {
      '1.0' => HttpProtocol.http10,
      _ => HttpProtocol.http11,
    };

ConnectionInfo connectionInfoFromHttpConnectionInfo(
  io.HttpConnectionInfo? info,
) {
  if (info == null) return ConnectionInfo.empty;
  return ConnectionInfo(
    remote: SocketAddress(
      address: IPAddress.fromBytes(info.remoteAddress.rawAddress),
      port: info.remotePort,
    ),
    localPort: info.localPort,
  );
}

Headers headersFromHttpRequest(io.HttpRequest request) {
  final store = MapHeaderStore();
  request.headers.forEach(
    (name, values) => store.set(HeaderName.lookup(name), values),
  );
  return Headers.fromStore(store);
}

/// The body of [request], typed by [headers].
///
/// A request that declares no length and is not chunked has none.
Body bodyFromHttpRequest(io.HttpRequest request, Headers headers) {
  final length = request.contentLength;
  if (length < 0 && !request.headers.chunkedTransferEncoding) {
    return Body.empty();
  }
  return Body.of(
    headers.tryGet(Headers.contentType),
    stream: request,
    contentLength: length < 0 ? null : length,
  );
}

/// Extension to convert a [ContentType] to a [MimeType].
extension ContentTypeExtension on io.ContentType {
  /// Converts a [ContentType] to a [MimeType].
  /// We are calling this method 'toMimeType' to avoid conflict with the 'mimeType' property.
  MimeType get toMimeType => MimeType(primaryType, subType);
}
