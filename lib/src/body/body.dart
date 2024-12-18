import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:http_parser/http_parser.dart';
import 'package:relic/relic.dart';
import 'package:relic/src/body/types/mime_type.dart';

/// The body of a request or response.
///
/// This tracks whether the body has been read. It's separate from [Message]
/// because the message may be changed with [Message.copyWith], but each instance
/// should share a notion of whether the body was read.
class Body {
  /// The contents of the message body.
  ///
  /// This will be `null` after [read] is called.
  Stream<Uint8List>? _stream;

  /// The length of the stream returned by [read], or `null` if that can't be
  /// determined efficiently.
  final int? contentLength;

  /// The content type of the body.
  ///
  /// This will be `null` if the body is empty.
  ///
  /// This is a convenience property that combines [mimeType] and [encoding].
  /// Example:
  /// ```dart
  /// var body = Body.fromString('hello', mimeType: MimeType.plainText);
  /// print(body.contentType); // ContentType(text/plain; charset=utf-8)
  /// ```
  final BodyType? contentType;

  Body._(
    this._stream,
    this.contentLength, {
    Encoding? encoding,
    MimeType? mimeType,
  }) : contentType = mimeType == null
            ? null
            : BodyType(mimeType: mimeType, encoding: encoding);

  /// Creates an empty body.
  factory Body.empty({
    Encoding encoding = utf8,
    MimeType mimeType = MimeType.plainText,
  }) =>
      Body._(
        Stream.empty(),
        0,
        encoding: encoding,
        mimeType: mimeType,
      );

  /// Creates a body from a [HttpRequest].
  factory Body.fromHttpRequest(HttpRequest request) {
    var contentType = request.headers.contentType;
    return Body._(
      request,
      request.contentLength <= 0 ? null : request.contentLength,
      encoding: Encoding.getByName(contentType?.charset),
      mimeType: contentType?.toMimeType,
    );
  }

  /// Creates a body from a string.
  factory Body.fromString(
    String body, {
    Encoding encoding = utf8,
    MimeType mimeType = MimeType.plainText,
  }) {
    Uint8List encoded = Uint8List.fromList(encoding.encode(body));
    return Body._(
      Stream.value(encoded),
      encoded.length,
      encoding: encoding,
      mimeType: mimeType,
    );
  }

  /// Creates a body from a [Stream] of [Uint8List].
  factory Body.fromDataStream(
    Stream<Uint8List> body, {
    Encoding? encoding = utf8,
    MimeType? mimeType = MimeType.plainText,
    int? contentLength,
  }) {
    return Body._(
      body,
      contentLength,
      encoding: encoding,
      mimeType: mimeType,
    );
  }

  /// Creates a body from a [Uint8List].
  factory Body.fromData(
    Uint8List body, {
    Encoding? encoding,
    MimeType mimeType = MimeType.binary,
  }) {
    return Body._(
      Stream.value(body),
      body.length,
      encoding: encoding,
      mimeType: mimeType,
    );
  }

  /// Returns a [Stream] representing the body.
  ///
  /// Can only be called once.
  Stream<Uint8List> read() {
    var stream = _stream;
    if (stream == null) {
      throw StateError(
        "The 'read' method can only be called once on a "
        'Request/Response object.',
      );
    }
    _stream = null;
    return stream;
  }

  /// Applies the headers to the response and encodes the body if transfer encoding is chunked.
  void applyHeadersAndEncodeBody(
    HttpResponse response, {
    TransferEncodingHeader? transferEncoding,
  }) {
    // If the body is empty (contentLength == 0), explicitly set Content-Length to 0
    // and remove any Transfer-Encoding header since no encoding is needed.
    if (contentLength == 0) {
      response.headers.contentLength = 0;
      response.headers.removeAll(Headers.transferEncodingHeader);
      return;
    }

    // Set the Content-Type header based on the MIME type of the body, if available.
    response.headers.contentType = _getContentType();

    // Retrieve the status code for further validation.
    int statusCode = response.statusCode;

    // Determine if chunked encoding should be applied.
    // Chunked encoding is enabled if:
    // - The status code is in the 200 range but not 204 (No Content) or 304 (Not Modified).
    // - The content length is unknown (contentLength == null).
    // - The content type is not "multipart/byteranges" (excluded as per HTTP spec).
    bool shouldEnableChunkedEncoding = statusCode >= 200 &&
        statusCode != 204 &&
        statusCode != 304 &&
        contentLength == null &&
        (contentType?.mimeType.isNotMultipartByteranges ?? false);

    // Check if chunked encoding is already enabled by inspecting the Transfer-Encoding header.
    bool isChunked = transferEncoding?.isChunked ?? false;

    var encodings = transferEncoding?.encodings ?? [];
    // If chunked encoding should be enabled but is not already, update the Transfer-Encoding header.
    if (shouldEnableChunkedEncoding && !isChunked) {
      // Add 'chunked' to the Transfer-Encoding header.
      encodings.add(TransferEncoding.chunked);

      // Apply chunked encoding to the response stream to encode the body in chunks.
      _stream = chunkedCoding.encoder.bind(_stream!).cast<Uint8List>();

      // Mark the response as chunked for further processing.
      isChunked = true;
    }

    if (isChunked) {
      // Remove any existing 'identity' transfer encoding, as it conflicts with 'chunked'.
      encodings.removeWhere((e) => e.name == TransferEncoding.identity.name);
      // Set the Transfer-Encoding header with the updated encodings.
      response.headers.set(Headers.transferEncodingHeader, encodings);

      // If the response is already chunked, remove the Content-Length header.
      // Chunked encoding does not require Content-Length because chunk sizes define the body length.
      response.headers.removeAll(Headers.contentLengthHeader);
    } else {
      // If chunked encoding is not enabled, set the Content-Length header to the known body length.
      response.headers.contentLength = contentLength ?? 0;
    }
  }

  /// Returns the content type of the body as a [ContentType].
  ///
  /// This is a convenience method that combines [mimeType] and [encoding].
  ContentType? _getContentType() {
    var mContentType = contentType;
    if (mContentType == null) return null;
    return ContentType(
      mContentType.mimeType.primaryType,
      mContentType.mimeType.subType,
      charset: mContentType.encoding?.name,
    );
  }
}
