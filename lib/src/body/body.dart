import 'dart:async';
import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';

import 'package:mime/mime.dart';

import 'types/body_type.dart';
import 'types/mime_type.dart';

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

  /// Body type is a combination of [mimeType] and [encoding].
  ///
  /// For incoming requests, this is populated from the request content type
  /// header.
  ///
  /// For outgoing responses, this field is used to create the content type
  /// header.
  ///
  /// This will be `null` if the body is empty.
  ///
  /// This is a convenience property that combines [mimeType] and [encoding].
  /// Example:
  /// ```dart
  /// var body = Body.fromString('hello', mimeType: MimeType.plainText);
  /// print(body.contentType); // ContentType(text/plain; charset=utf-8)
  /// ```
  final BodyType? bodyType;

  Body._(
    this._stream,
    this.contentLength, {
    final Encoding? encoding,
    final MimeType? mimeType,
  }) : bodyType = mimeType == null
            ? null
            : BodyType(mimeType: mimeType, encoding: encoding);

  /// Creates an empty body.
  ///
  /// Example:
  /// ```dart
  /// final emptyBody = Body.empty();
  /// print(emptyBody.contentLength); // 0
  /// ```
  factory Body.empty() => Body._(const Stream.empty(), 0);

  /// Creates a body from a string.
  ///
  /// If [mimeType] is not provided, it will be inferred from the string.
  /// It is more performant to set it explicitly.
  ///
  /// Examples:
  /// ```dart
  /// // Simple text
  /// final body = Body.fromString('Hello, World!');
  ///
  /// // JSON with automatic detection
  /// final jsonBody = Body.fromString('{"message": "Hello"}');
  /// // Automatically detects application/json MIME type
  ///
  /// // HTML with automatic detection
  /// final htmlBody = Body.fromString('<!DOCTYPE html><html>...</html>');
  /// // Automatically detects text/html MIME type
  ///
  /// // With explicit MIME type and encoding
  /// final customBody = Body.fromString(
  ///   'Custom content',
  ///   mimeType: MimeType.plainText,
  ///   encoding: latin1,
  /// );
  /// ```
  factory Body.fromString(
    final String body, {
    final Encoding encoding = utf8,
    MimeType? mimeType,
  }) {
    final Uint8List encoded = Uint8List.fromList(encoding.encode(body));

    mimeType ??= _tryInferTextMimeTypeFrom(body) ?? MimeType.plainText;

    return Body._(
      Stream.value(encoded),
      encoded.length,
      encoding: encoding,
      mimeType: mimeType,
    );
  }

  static MimeType? _tryInferTextMimeTypeFrom(final String content) {
    var firstNonWhiteSpace = 0;
    final end = content.length;
    while (firstNonWhiteSpace < end &&
        _isWhitespace(content[firstNonWhiteSpace])) {
      firstNonWhiteSpace++;
    }

    final prefix = content.substring(firstNonWhiteSpace,
        min(end, firstNonWhiteSpace + 14)); // 14 max length needed

    if (prefix.startsWith('{') || prefix.startsWith('[')) {
      return MimeType.json;
    }

    if (prefix.startsWith('<?xml')) {
      return MimeType.xml;
    }

    if (prefix.startsWith('<!DOCTYPE html') ||
        prefix.startsWith('<!doctype html') ||
        prefix.startsWith('<html')) {
      return MimeType.html;
    }

    return null; // give up
  }

  /// Checks if a character is whitespace.
  static bool _isWhitespace(final String char) {
    return char == ' ' || char == '\t' || char == '\n' || char == '\r';
  }

  /// Creates a body from a [Stream] of [Uint8List].
  ///
  /// This is useful for large files or streaming data where you don't want
  /// to load everything into memory at once.
  ///
  /// Examples:
  /// ```dart
  /// // Stream with known length (recommended for better HTTP performance)
  /// final streamBody = Body.fromDataStream(
  ///   fileStream,
  ///   mimeType: MimeType.pdf,
  ///   contentLength: fileSize,
  /// );
  ///
  /// // Stream with unknown length (uses chunked encoding)
  /// final dynamicBody = Body.fromDataStream(
  ///   dynamicStream,
  ///   mimeType: MimeType.json,
  ///   // contentLength omitted for chunked encoding
  /// );
  /// ```
  factory Body.fromDataStream(
    final Stream<Uint8List> body, {
    final Encoding? encoding,
    final MimeType? mimeType = MimeType.octetStream,
    final int? contentLength,
  }) {
    return Body._(
      body,
      contentLength,
      encoding: encoding ?? (mimeType?.isText == true ? utf8 : null),
      mimeType: mimeType,
    );
  }

  static final _resolver = MimeTypeResolver();

  /// Creates a body from a [Uint8List].
  ///
  /// Will try to infer the [mimeType] if it is not provided,
  /// This will only work for some binary formats, and falls
  /// back to [MimeType.octetStream].
  ///
  /// Examples:
  /// ```dart
  /// // Binary data with automatic format detection
  /// final imageData = Uint8List.fromList([0x89, 0x50, 0x4E, 0x47, ...]);
  /// final imageBody = Body.fromData(imageData);
  /// // Automatically detects image/png from magic bytes
  ///
  /// // Binary data with explicit MIME type
  /// final binaryBody = Body.fromData(
  ///   data,
  ///   mimeType: MimeType.octetStream,
  /// );
  ///
  /// // PDF document detection
  /// final pdfBytes = utf8.encode('%PDF-1.4...');
  /// final pdfBody = Body.fromData(pdfBytes);
  /// // Automatically detects application/pdf
  /// ```
  factory Body.fromData(
    final Uint8List body, {
    final Encoding? encoding,
    MimeType? mimeType,
  }) {
    if (mimeType == null) {
      final mimeString = _resolver.lookup('', headerBytes: body);
      mimeType = mimeString == null ? null : MimeType.parse(mimeString);
    }
    return Body._(
      Stream.value(body),
      body.length,
      encoding: encoding ?? (mimeType?.isText == true ? utf8 : null),
      mimeType: mimeType ?? MimeType.octetStream,
    );
  }

  /// Returns a [Stream] representing the body.
  ///
  /// Can only be called once to prevent accidental double-consumption
  /// and ensure predictable behavior.
  ///
  /// Examples:
  /// ```dart
  /// final body = Body.fromString('test');
  ///
  /// // First read - OK
  /// final stream1 = body.read();
  ///
  /// // Second read - throws StateError
  /// try {
  ///   final stream2 = body.read(); // ❌ Error!
  /// } catch (e) {
  ///   print(e); // "The 'read' method can only be called once"
  /// }
  ///
  /// // For processing large uploads chunk by chunk:
  /// final uploadStream = request.body.read();
  /// await for (final chunk in uploadStream) {
  ///   // Process chunk by chunk
  ///   await processChunk(chunk);
  /// }
  /// ```
  Stream<Uint8List> read() {
    final stream = _stream;
    if (stream == null) {
      throw StateError(
        "The 'read' method can only be called once on a "
        'Request/Response object.',
      );
    }
    _stream = null;
    return stream;
  }
}
