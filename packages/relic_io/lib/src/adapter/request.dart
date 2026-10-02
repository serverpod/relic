import 'dart:convert';
import 'dart:io' as io;

import 'package:relic_core/relic_core.dart';

/// Creates a new [Request] from an [io.HttpRequest].
Request fromHttpRequest(io.HttpRequest request) {
  return RequestInternal.create(
    Method.parse(request.method),
    request.requestedUri,
    request,
    protocol: switch (request.protocolVersion) {
      '1.0' => HttpProtocol.http10,
      _ => HttpProtocol.http11,
    },
    headers: headersFromHttpRequest(request),
    body: bodyFromHttpRequest(request),
    connectionInfo: connectionInfoFromHttpConnectionInfo(
      request.connectionInfo,
    ),
  );
}

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
  return Headers.build((mh) {
    request.headers.forEach((k, v) => mh[k] = v);
  });
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
