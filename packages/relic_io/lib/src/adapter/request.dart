import 'dart:io' as io;

import 'package:relic_core/relic_core.dart';

import 'request_body.dart';

/// Creates a new [Request] from an [io.HttpRequest], on [exchange], with
/// [create]. Its body reads [body].
///
/// Throws [FormatException] for a target that does not decode. The core
/// answers that with 400 before any handler runs.
Request fromHttpRequest(
  io.HttpRequest request,
  AdapterExchange exchange,
  RequestFactory create,
  IORequestBody? body,
) {
  final url = request.requestedUri;
  final target = RequestTarget.fromUri(url)..validate();
  final headers = headersFromHttpRequest(request);
  return create(
    Method.parse(request.method),
    exchange,
    url: url,
    target: target,
    headers: headers,
    body: bodyFromHttpRequest(request, headers, body),
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

/// The body of [request], typed by [headers], read from [body].
///
/// A request without [body] has none.
Body bodyFromHttpRequest(
  io.HttpRequest request,
  Headers headers,
  IORequestBody? body,
) {
  if (body == null) return Body.empty();
  final length = request.contentLength;
  return Body.of(
    headers.tryGet(Headers.contentType),
    stream: body.stream,
    contentLength: length < 0 ? null : length,
  );
}

/// Extension to convert a [ContentType] to a [MimeType].
extension ContentTypeExtension on io.ContentType {
  /// Converts a [ContentType] to a [MimeType].
  /// We are calling this method 'toMimeType' to avoid conflict with the 'mimeType' property.
  MimeType get toMimeType => MimeType(primaryType, subType);
}
