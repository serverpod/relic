import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

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
  factory Body.fromString(
    final String body, {
    final Encoding encoding = utf8,
    final MimeType mimeType = MimeType.plainText,
  }) {
    final Uint8List encoded = Uint8List.fromList(encoding.encode(body));
    return Body._(
      Stream.value(encoded),
      encoded.length,
      encoding: encoding,
      mimeType: mimeType,
    );
  }

  /// Creates a body from a [Stream] of [Uint8List].
  factory Body.fromDataStream(
    final Stream<Uint8List> body, {
    final Encoding? encoding = utf8,
    final MimeType? mimeType = MimeType.plainText,
    final int? contentLength,
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
    final Uint8List body, {
    final Encoding? encoding,
    final MimeType mimeType = MimeType.octetStream,
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
