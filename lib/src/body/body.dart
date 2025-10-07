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
  factory Body.empty() => Body._(const Stream.empty(), 0);

  /// Creates a body from a string.
  ///
  /// If [mimeType] is not provided, it will be inferred from the string.
  /// It is more performant to set it explicitly.
  factory Body.fromString(
    final String body, {
    final Encoding encoding = utf8,
    MimeType? mimeType,
  }) {
    final Uint8List encoded = Uint8List.fromList(encoding.encode(body));

    // Try to infer mime type from content, if not provided
    mimeType ??= _tryInferTextMimeTypeFrom(body) ?? MimeType.plainText;

    return Body._(
      Stream.value(encoded),
      encoded.length,
      encoding: encoding,
      mimeType: mimeType,
    );
  }

  /// Try to infer MIME type from string content by analyzing the content prefix
  ///
  /// Can infer text/json, text/xml, text/html, text/css.
  static MimeType? _tryInferTextMimeTypeFrom(final String content) {
    // Find first non-whitespace character to avoid allocating a trimmed string
    var begin = 0;
    final end = content.length;
    while (begin < end && _isWhitespace(content[begin])) {
      begin++;
    }

    // Extract small marker prefix
    final prefix =
        content.substring(begin, min(end, begin + 14)); // 14 max length needed

    // Check for JSON (this is super crude)
    if (prefix.startsWith('{') || prefix.startsWith('[')) {
      return MimeType.json;
    }

    // Check for XML (including variants like <?xml)
    if (prefix.startsWith('<?xml')) {
      return MimeType.xml;
    }

    // Check for HTML (including DOCTYPE and common HTML tags)
    if (prefix.startsWith('<!DOCTYPE html') ||
        prefix.startsWith('<!doctype html') ||
        prefix.startsWith('<html')) {
      return MimeType.html;
    }

    return null; // give up
  }

  /// Checks if a character is whitespace.
  static bool _isWhitespace(final String char) {
    // Common whitespace characters
    return char == ' ' || char == '\t' || char == '\n' || char == '\r';
  }

  /// Creates a body from a [Stream] of [Uint8List].
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
  factory Body.fromData(
    final Uint8List body, {
    final Encoding? encoding,
    MimeType? mimeType,
  }) {
    // Attempt to infer mimeType, if not set
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
  /// Can only be called once.
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
