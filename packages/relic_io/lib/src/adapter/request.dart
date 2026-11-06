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
    body: bodyFromHttpRequest(request, onBodyEnd: onBodyEnd),
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

/// Whether the connection goes on after the response to [request].
///
/// Every Connection option counts, and close wins (RFC 9112 9.3), where
/// dart:io's `persistentConnection` follows the later of the two.
bool keepAliveOf(io.HttpRequest request) {
  final options =
      request.headers[io.HttpHeaders.connectionHeader] ?? const <String>[];
  bool lists(String option) =>
      options.any((value) => value.toLowerCase() == option);
  if (lists('close')) return false;
  return request.protocolVersion != '1.0' || lists('keep-alive');
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

Headers headersFromHttpRequest(io.HttpRequest request) =>
    Headers.fromStore(_HttpHeadersStore(request.headers));

/// A [HeaderStore] that reads parsed [io.HttpHeaders] in place.
///
/// dart:io's parser refuses a value with CR, LF or NUL, and the headers are
/// immutable once parsed, so no value is copied or checked again. Its name
/// check, as of SDK 3.13, skips the first byte of a name and lets DEL pass,
/// so every name goes through [HeaderName.lookup] here, which throws for
/// one that is not a token. [names] follow dart:io's order, not the wire's.
final class _HttpHeadersStore extends HeaderStore {
  final io.HttpHeaders _headers;

  @override
  final List<HeaderName> names = [];

  _HttpHeadersStore(this._headers) {
    _headers.forEach((name, _) => names.add(HeaderName.lookup(name)));
  }

  @override
  Iterable<String> values(HeaderName name) =>
      _headers[name.lower] ?? const <String>[];
}

/// The body of [request], untyped. The core types it from the headers.
///
/// A request that declares no length and is not chunked has none. The
/// request goes in lazily: a body rejected unread is then never listened to,
/// and dart:io drains it after the response instead of resetting the client.
/// [onBodyEnd] runs when a chunked body has been read to its end.
Body bodyFromHttpRequest(io.HttpRequest request, {void Function()? onBodyEnd}) {
  final length = request.contentLength;
  if (length < 0 && !request.headers.chunkedTransferEncoding) {
    return Body.empty();
  }
  final chunked = length < 0;
  return Body(
    open: () => chunked && onBodyEnd != null
        ? request.transform(_endingWith(onBodyEnd))
        : request,
    contentLength: chunked ? null : length,
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
