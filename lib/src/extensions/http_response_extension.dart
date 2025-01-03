import 'package:relic/relic.dart';
import 'dart:io' as io;

/// Extension for [io.HttpResponse] to apply headers and body.
extension HttpResponseExtension on io.HttpResponse {
  /// Apply headers and body to the response.
  void applyHeaders(Headers headers, Body body) {
    var responseHeaders = this.headers;
    responseHeaders.clear();

    // Apply headers
    var mappedHeaders = headers.toMap();
    for (var entry in mappedHeaders.entries) {
      responseHeaders.set(entry.key, entry.value);
    }

    // Set the Content-Type header based on the MIME type of the body.
    responseHeaders.contentType = body.getContentType();

    // If the content length is known, set it and remove the Transfer-Encoding header.
    var contentLength = body.contentLength;
    if (contentLength != null) {
      responseHeaders
        ..contentLength = contentLength
        ..removeAll(Headers.transferEncodingHeader);
      return;
    }

    // Check if the content type is multipart/byteranges.
    var bodyMimeType = body.contentType?.mimeType;
    bool isMultipartByteranges =
        bodyMimeType?.primaryType == MimeType.multipartByteranges.primaryType &&
            bodyMimeType?.subType == MimeType.multipartByteranges.subType;

    // Determine if chunked encoding should be applied.
    bool shouldEnableChunkedEncoding = statusCode >= 200 &&
        // 204 is no content
        statusCode != 204 &&
        // 304 is not modified
        statusCode != 304 &&
        // If the content type is not multipart/byteranges, chunked encoding is applied.
        !isMultipartByteranges;

    // Prepare transfer encodings.
    var encodings = headers.transferEncoding?.encodings ?? [];
    bool isChunked = headers.transferEncoding?.isChunked ?? false;

    if (shouldEnableChunkedEncoding && !isChunked) {
      encodings.add(TransferEncoding.chunked);
      isChunked = true;
    }

    if (!isChunked) {
      // Set Content-Length to 0 if chunked encoding is not enabled.
      responseHeaders.contentLength = 0;
      return;
    }

    // Remove conflicting 'identity' encoding if present.
    encodings.removeWhere((e) => e.name == TransferEncoding.identity.name);

    // Set Transfer-Encoding header and remove Content-Length as it is not needed for chunked encoding.
    responseHeaders
      ..set(
        Headers.transferEncodingHeader,
        encodings.map((e) => e.name).toList(),
      )
      ..removeAll(Headers.contentLengthHeader);
  }
}
