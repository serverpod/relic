import 'dart:io' as io;

import 'package:relic_core/adapter.dart';
import 'package:relic_core/relic_core.dart';

/// Extension for [io.HttpResponse] to write the head from a framing.
extension HttpResponseExtension on io.HttpResponse {
  /// Replaces the response headers with [headers], minus the ones [framing]
  /// decides, and then adds the framing's own.
  void applyFraming(Headers headers, ResponseFraming framing) {
    final out = this.headers;
    out.clear();
    for (final name in headers.names) {
      if (ResponseFraming.isFramingHeader(name)) continue;
      out.set(name.lower, headers.values(name));
    }
    final contentType = framing.contentType;
    if (contentType != null) out.set(HeaderName.contentType.lower, contentType);
    final date = framing.date;
    if (date != null) out.set(HeaderName.date.lower, date);
    // dart:io writes `close` itself on an HTTP/1.1 connection that is not
    // persistent, and an HTTP/1.0 status line already implies it. The
    // keep-alive an HTTP/1.0 client needs to hear is left to us.
    if (framing.connection == ConnectionHeaderType.keepAlive) {
      out.set(
        HeaderName.connection.lower,
        ConnectionHeaderType.keepAlive.value,
      );
    }
    final transferEncoding = framing.transferEncoding;
    final contentLength = framing.contentLength;
    if (contentLength != null) {
      out.contentLength = contentLength;
    } else if (transferEncoding != null) {
      // dart:io chunks the body itself when the codings say chunked.
      out.set(HeaderName.transferEncoding.lower, transferEncoding);
    } else {
      // Nothing frames the body. The connection's end does.
      out.chunkedTransferEncoding = false;
    }
  }
}
