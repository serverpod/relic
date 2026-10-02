import 'dart:io' as io;

import 'package:relic_core/relic_core.dart';

/// Extension for [io.HttpResponse] to apply headers and body.
extension HttpResponseExtension on io.HttpResponse {
  /// Apply headers and body to the response.
  ///
  /// Transfer encoding 'chunked' may be added to the response if it is required
  /// and does not conflict with existing headers.
  void applyHeaders(Headers headers, Body body) {
    final responseHeaders = this.headers;
    responseHeaders.clear();

    // Apply all headers from the provided headers map.
    for (final name in headers.names) {
      responseHeaders.set(name.lower, headers.values(name));
    }

    // Set Content-Type based on the MIME type of the body.
    responseHeaders.contentType = body.getContentType();

    // If the content length is already set, then return.
    if (responseHeaders.contentLength >= 0) return;

    // If the content length is known, set it and return.
    final contentLength = body.contentLength;
    if (contentLength != null) {
      responseHeaders.contentLength = contentLength;
      return;
    }

    // Otherwise, we need to consider chunked encoding. Copy into a growable
    // list: TransferEncodingHeader.encodings is unmodifiable, so adding the
    // chunked coding below would otherwise throw.
    final encodings = [...?headers.transferEncoding?.encodings];
    final isChunked = headers.transferEncoding?.isChunked ?? false;
    final isIdentity = headers.transferEncoding?.isIdentity ?? false;
    final shouldEnableChunkedEncoding = _shouldEnableChunkedEncoding(body);

    // If the transfer encoding is not chunked or identity and chunked encoding
    // should be enabled, add chunked encoding to the response.
    if (!isChunked && !isIdentity && shouldEnableChunkedEncoding) {
      encodings.add(TransferEncoding.chunked);
    }

    // Set the transfer encoding header (only when there is a coding to emit;
    // an empty list would otherwise set an empty Transfer-Encoding).
    if (encodings.isNotEmpty) {
      responseHeaders.set(
        HeaderName.transferEncoding.lower,
        encodings.map((e) => e.name).toList(),
      );
    }
  }

  /// Whether the response is sent with chunked transfer encoding. A status
  /// that carries no body is not, and neither is a multipart/byteranges
  /// response, which frames itself with Content-Range (RFC 7233 4.1).
  bool _shouldEnableChunkedEncoding(Body body) =>
      statusMayHaveBody(statusCode) && !body.isMultipartByteranges;
}

/// Extension for [MimeType] to check if it is multipart/byteranges.
extension on Body {
  /// Check if the body is multipart/byteranges.
  bool get isMultipartByteranges {
    const multipartByteranges = MimeType.multipartByteranges;
    return bodyType?.mimeType.primaryType == multipartByteranges.primaryType &&
        bodyType?.mimeType.subType == multipartByteranges.subType;
  }
}

extension on TransferEncodingHeader {
  /// Checks if the Transfer-Encoding contains the specified encoding.
  bool _exists(TransferEncoding encoding) {
    return encodings.any((e) => e.name == encoding.name);
  }

  /// Checks if the Transfer-Encoding contains `chunked`.
  bool get isChunked => _exists(TransferEncoding.chunked);

  /// Checks if the Transfer-Encoding contains `identity`.
  bool get isIdentity => _exists(TransferEncoding.identity);
}

extension on Body {
  /// Returns the content type of the body as a [ContentType].
  ///
  /// Combines the mime type, encoding and parameters of [bodyType].
  io.ContentType? getContentType() {
    final mBodyType = bodyType;
    if (mBodyType == null) return null;
    mBodyType.validate();
    final mimeType = mBodyType.mimeType;
    return io.ContentType(
      mimeType.primaryType,
      mimeType.subType,
      charset: mBodyType.encoding?.name,
      parameters: mBodyType.parameters,
    );
  }
}
