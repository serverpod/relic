import 'dart:convert';

import 'mime_type.dart';

/// A body type that combines MIME type and encoding information.
///
/// This class encapsulates both the MIME type (what kind of content this is)
/// and the optional encoding (how text content is encoded into bytes).
///
/// Examples:
/// ```dart
/// // Text content with encoding
/// const textType = BodyType(
///   mimeType: MimeType.plainText,
///   encoding: utf8,
/// );
/// print(textType.toHeaderValue()); // "text/plain; charset=utf-8"
///
/// // Binary content without encoding
/// const binaryType = BodyType(mimeType: MimeType.octetStream);
/// print(binaryType.toHeaderValue()); // "application/octet-stream"
///
/// // JSON content
/// const jsonType = BodyType(
///   mimeType: MimeType.json,
///   encoding: utf8,
/// );
/// print(jsonType.toHeaderValue()); // "application/json; charset=utf-8"
/// ```
class BodyType {
  /// The mime type of the body.
  final MimeType mimeType;

  /// The encoding of the body.
  final Encoding? encoding;

  const BodyType({required this.mimeType, this.encoding});

  /// Returns the value to use for the Content-Type header.
  ///
  /// If encoding is present, it's included as a charset parameter.
  ///
  /// Examples:
  /// ```dart
  /// const bodyType = BodyType(mimeType: MimeType.plainText, encoding: utf8);
  /// print(bodyType.toHeaderValue()); // "text/plain; charset=utf-8"
  ///
  /// const binaryType = BodyType(mimeType: MimeType.octetStream);
  /// print(binaryType.toHeaderValue()); // "application/octet-stream"
  /// ```
  String toHeaderValue() {
    if (encoding != null) {
      return '${mimeType.toHeaderValue()}; charset=${encoding!.name}';
    } else {
      return mimeType.toHeaderValue();
    }
  }

  @override
  String toString() => 'BodyType(mimeType: $mimeType, encoding: $encoding)';
}
