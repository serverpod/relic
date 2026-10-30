import 'dart:async';
import 'dart:io' as io;
import 'dart:typed_data';

import 'package:relic_core/relic_core.dart';

/// Creates a new [Request] from an [io.HttpRequest], on [exchange], with
/// [create].
///
/// Throws [FormatException] for a target that does not decode. The core
/// answers that with 400 before any handler runs.
Request fromHttpRequest(
  io.HttpRequest request,
  AdapterExchange exchange,
  RequestFactory create, {
  void Function()? onBodyEnd,
}) {
  final url = request.requestedUri;
  final target = RequestTarget.fromUri(url)..validate();
  final headers = headersFromHttpRequest(request);
  return create(
    Method.parse(request.method),
    exchange,
    url: url,
    target: target,
    headers: headers,
    body: bodyFromHttpRequest(request, headers, onBodyEnd: onBodyEnd),
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
/// A request that declares no length and is not chunked has none. The
/// request goes in lazily: a body rejected unread is then never listened to,
/// and dart:io drains it after the response instead of resetting the client.
/// [onBodyEnd] runs when a chunked body has been read to its end.
Body bodyFromHttpRequest(
  io.HttpRequest request,
  Headers headers, {
  void Function()? onBodyEnd,
}) {
  final length = request.contentLength;
  if (length < 0 && !request.headers.chunkedTransferEncoding) {
    return Body.empty();
  }
  final chunked = length < 0;
  final contentType = headers.tryGet(Headers.contentType);
  return Body(
    open: () => chunked && onBodyEnd != null
        ? request.transform(_endingWith(onBodyEnd))
        : request,
    contentLength: chunked ? null : length,
    bodyType: contentType == null
        ? null
        : BodyType.fromContentType(contentType),
  );
}

StreamTransformer<Uint8List, Uint8List> _endingWith(void Function() onDone) =>
    StreamTransformer.fromHandlers(
      handleDone: (sink) {
        onDone();
        sink.close();
      },
    );

/// Extension to convert a [ContentType] to a [MimeType].
extension ContentTypeExtension on io.ContentType {
  /// Converts a [ContentType] to a [MimeType].
  /// We are calling this method 'toMimeType' to avoid conflict with the 'mimeType' property.
  MimeType get toMimeType => MimeType(primaryType, subType);
}
