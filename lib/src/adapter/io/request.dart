import 'dart:convert';
import 'dart:io' as io;

import '../../../relic.dart';
import '../connection_info.dart';
import '../ip_address.dart';

/// Creates a new [Request] from an [io.HttpRequest].
///
/// [strictHeaders] determines whether to strictly enforce header parsing
/// rules. [poweredByHeader] sets the value of the `X-Powered-By` header.
Request fromHttpRequest(
  final io.HttpRequest request, {
  final bool strictHeaders = false,
  final String? poweredByHeader,
}) {
  return Request(
    RequestMethod.parse(request.method),
    request.requestedUri,
    protocolVersion: request.protocolVersion,
    headers: headersFromHttpRequest(request),
    body: bodyFromHttpRequest(request),
    context: {},
  );
}

ConnectionInfo connectionInfoFromHttpRequest(final io.HttpRequest request) {
  final info = request.connectionInfo;
  if (info == null) return ConnectionInfo.unknown();
  return ConnectionInfo(
      remoteAddress: IPAddress.fromBytes(info.remoteAddress.rawAddress),
      remotePort: info.remotePort,
      localPort: info.localPort);
}

Headers headersFromHttpRequest(final io.HttpRequest request) {
  return Headers.build((final mh) {
    request.headers.forEach((final k, final v) => mh[k] = v);
  });
}

/// Creates a body from a [HttpRequest].
Body bodyFromHttpRequest(final io.HttpRequest request) {
  final contentType = request.headers.contentType;
  return Body.fromDataStream(
    request,
    contentLength: request.contentLength <= 0 ? null : request.contentLength,
    encoding: Encoding.getByName(contentType?.charset),
    mimeType: contentType?.toMimeType,
  );
}

/// Extension to convert a [ContentType] to a [MimeType].
extension ContentTypeExtension on io.ContentType {
  /// Converts a [ContentType] to a [MimeType].
  /// We are calling this method 'toMimeType' to avoid conflict with the 'mimeType' property.
  MimeType get toMimeType => MimeType(primaryType, subType);
}
