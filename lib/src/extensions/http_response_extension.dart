import 'package:relic/relic.dart';
import 'dart:io' as io;

import 'package:relic/src/body/types/mime_type.dart';

/// Extension for [io.HttpResponse] to apply headers and body.
extension HttpResponseExtension on io.HttpResponse {
  /// Apply headers and body to the response.
  void applyHeaders(Headers headers, Body body) {
    var httpHeaders = this.headers;
    httpHeaders.clear();

    // Apply headers
    var mappedHeaders = headers.toMap();
    for (var entry in mappedHeaders.entries) {
      var key = entry.key;
      var value = entry.value;
      httpHeaders.set(key, value);
    }

    // Set the Content-Type header based on the MIME type of the body.
    httpHeaders.contentType = body.getContentType();

    // If the content length is known, set it and remove the Transfer-Encoding header.
    if (body.contentLength != null) {
      httpHeaders
        ..contentLength = body.contentLength!
        ..removeAll(Headers.transferEncodingHeader);
      return;
    }

    // Determine if chunked encoding should be applied.
    bool shouldEnableChunkedEncoding = statusCode >= 200 &&
        // 204 is no content
        statusCode != 204 &&
        // 304 is not modified
        statusCode != 304 &&
        // If the content length is not known, chunked encoding is applied.
        body.contentLength == null &&
        // If the content type is not multipart/byteranges, chunked encoding is applied.
        (body.contentType?.mimeType.isMultipartByteranges == false);

    // Prepare transfer encodings.
    var encodings = headers.transferEncoding?.encodings ?? [];
    bool isChunked = headers.transferEncoding?.isChunked ?? false;

    if (shouldEnableChunkedEncoding && !isChunked) {
      encodings.add(TransferEncoding.chunked);
      isChunked = true;
    }

    if (isChunked) {
      // Remove conflicting 'identity' encoding if present.
      encodings.removeWhere((e) => e.name == TransferEncoding.identity.name);

      // Set Transfer-Encoding header and remove Content-Length as it is not needed for chunked encoding.
      httpHeaders
        ..set(
          Headers.transferEncodingHeader,
          encodings.map((e) => e.name).toList(),
        )
        ..removeAll(Headers.contentLengthHeader);
    } else {
      // Set Content-Length to 0 if chunked encoding is not enabled.
      httpHeaders.contentLength = 0;
    }
  }
}
