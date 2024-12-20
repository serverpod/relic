import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

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

  /// Applies transfer encoding headers and content length to the response.
  void applyHeaders(
    HttpResponse response, {
    TransferEncodingHeader? transferEncoding,
  }) {
    // Set the Content-Type header based on the MIME type of the body.
    response.headers.contentType = _getContentType();

    // If the content length is known, set it and remove the Transfer-Encoding header.
    if (contentLength != null) {
      response.headers
        ..contentLength = contentLength!
        ..removeAll(Headers.transferEncodingHeader);
      return;
    }

    // Determine if chunked encoding should be applied.
    bool shouldEnableChunkedEncoding = response.statusCode >= 200 &&
        // 204 is no content
        response.statusCode != 204 &&
        // 304 is not modified
        response.statusCode != 304 &&
        // If the content length is not known, chunked encoding is applied.
        contentLength == null &&
        // If the content type is not multipart/byteranges, chunked encoding is applied.
        (contentType?.mimeType.isNotMultipartByteranges ?? true);

    // Prepare transfer encodings.
    var encodings = transferEncoding?.encodings ?? [];
    bool isChunked = transferEncoding?.isChunked ?? false;

    if (shouldEnableChunkedEncoding && !isChunked) {
      encodings.add(TransferEncoding.chunked);
      isChunked = true;
    }

    if (isChunked) {
      // Remove conflicting 'identity' encoding if present.
      encodings.removeWhere((e) => e.name == TransferEncoding.identity.name);

      // Set Transfer-Encoding header and remove Content-Length as it is not needed for chunked encoding.
      response.headers
        ..set(Headers.transferEncodingHeader,
            encodings.map((e) => e.name).toList())
        ..removeAll(Headers.contentLengthHeader);
    } else {
      // Set Content-Length to 0 if chunked encoding is not enabled.
      response.headers.contentLength = 0;
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
