import 'dart:convert';
import 'dart:io' as io;

import 'package:relic_core/relic_core.dart';

/// Creates a new [Request] from an [io.HttpRequest].
///
/// Throws [FormatException] for a target that does not decode. The core
/// answers that with 400 before any handler runs.
Request fromHttpRequest(io.HttpRequest request) {
  final url = request.requestedUri;
  RequestTarget.fromUri(url).validate();
  return RequestInternal.create(
    Method.parse(request.method),
    url,
    request,
    protocol: httpProtocolOf(request),
    headers: headersFromHttpRequest(request),
    body: bodyFromHttpRequest(request),
    connectionInfo: connectionInfoFromHttpConnectionInfo(
      request.connectionInfo,
    ),
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

/// Creates a body from a [HttpRequest].
Body bodyFromHttpRequest(io.HttpRequest request) {
  final contentType = request.headers.contentType;
  return Body.fromDataStream(
    request,
    contentLength: request.contentLength <= 0 ? null : request.contentLength,
    encoding: Encoding.getByName(contentType?.charset),
    mimeType: contentType?.toMimeType,
    parameters: {
      if (contentType != null)
        for (final MapEntry(:key, :value) in contentType.parameters.entries)
          if (key != 'charset' && value != null && _isWritable(key, value))
            key: value,
    },
  );
}

/// Whether relic can write a Content-Type parameter back to a header.
bool _isWritable(String name, String value) {
  if (!Token.isValid(name)) return false;
  try {
    ParameterValue(value);
    return true;
  } on FormatException {
    return false;
  }
}

/// Extension to convert a [ContentType] to a [MimeType].
extension ContentTypeExtension on io.ContentType {
  /// Converts a [ContentType] to a [MimeType].
  /// We are calling this method 'toMimeType' to avoid conflict with the 'mimeType' property.
  MimeType get toMimeType => MimeType(primaryType, subType);
}
