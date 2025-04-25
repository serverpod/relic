import 'dart:io' as io;

import '../../../relic.dart';
import '../../headers/standard_headers_extensions.dart';

/// Extension for [io.HttpResponse] to apply headers and body.
extension HttpResponseExtension on io.HttpResponse {
  /// Apply headers and body to the response.
  ///
  /// Transfer encoding 'chunked' may be added to the response if it is required
  /// and does not conflict with existing headers.
  void applyHeaders(final Headers headers, final Body body) {
    final responseHeaders = this.headers;
    responseHeaders.clear();

    // Apply all headers from the provided headers map.
    for (final entry in headers.entries) {
      responseHeaders.set(entry.key, entry.value);
    }

    // Set Content-Type based on the MIME type of the body.
    responseHeaders.contentType = body.getContentType();

    // If the content length is known, set it and return.
    final contentLength = body.contentLength;
    if (contentLength != null) {
      responseHeaders.contentLength = contentLength;
      return;
    }

    final encodings = headers.transferEncoding?.encodings ?? [];
    final isChunked = headers.transferEncoding?.isChunked ?? false;
    final isIdentity = headers.transferEncoding?.isIdentity ?? false;
    final shouldEnableChunkedEncoding = _shouldEnableChunkedEncoding(body);

    // If the transfer encoding is not chunked or identity and chunked encoding
    // should be enabled, add chunked encoding to the response.
    if (!isChunked && !isIdentity && shouldEnableChunkedEncoding) {
      encodings.add(TransferEncoding.chunked);
    }

    // Set the transfer encoding header.
    responseHeaders.set(
      Headers.transferEncodingHeader,
      encodings.map((final e) => e.name).toList(),
    );
  }

  /// Check if chunked encoding should be applied.
  ///
  /// References:
  /// - RFC 7230, Section 3.3: "Message Body" (https://datatracker.ietf.org/doc/html/rfc7230#section-3.3)
  ///   - Responses with status codes 1xx (Informational), 204 (No Content), and 304 (Not Modified) MUST NOT include a body.
  ///   - As these responses lack a body, there is no content to encode, making `Transfer-Encoding` unnecessary
  ///     and inapplicable in such cases.
  ///
  /// - RFC 7233, Section 4.1: "Multipart/byteranges" (https://datatracker.ietf.org/doc/html/rfc7233#section-4.1)
  ///   - Multipart/byteranges responses use the `Content-Range` mechanism instead of chunked transfer encoding.
  ///
  /// This logic ensures compliance with HTTP/1.1 by:
  /// - Excluding status codes 1xx, 204, and 304 from chunked encoding.
  /// - Handling multipart/byteranges responses according to their specific requirements.
  bool _shouldEnableChunkedEncoding(final Body body) {
    return
        // Exclude 1xx status codes (no body allowed).
        statusCode >= 200 &&
            // Exclude 204 (No Content) status code (no body allowed).
            statusCode != 204 &&
            // Exclude 304 (Not Modified) status code (no body allowed).
            statusCode != 304 &&
            // Exclude multipart/byteranges responses (handled via Content-Range).
            !body.isMultipartByteranges;
  }
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
  bool _exists(final TransferEncoding encoding) {
    return encodings.any((final e) => e.name == encoding.name);
  }

  /// Checks if the Transfer-Encoding contains `chunked`.
  bool get isChunked => _exists(TransferEncoding.chunked);

  /// Checks if the Transfer-Encoding contains `identity`.
  bool get isIdentity => _exists(TransferEncoding.identity);
}

extension on Body {
  /// Returns the content type of the body as a [ContentType].
  ///
  /// This is a convenience method that combines [mimeType] and [encoding].
  io.ContentType? getContentType() {
    final mBodyType = bodyType;
    if (mBodyType == null) return null;
    return io.ContentType(
      mBodyType.mimeType.primaryType,
      mBodyType.mimeType.subType,
      charset: mBodyType.encoding?.name,
    );
  }
}
