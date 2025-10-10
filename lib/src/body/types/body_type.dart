import 'dart:convert';

import 'mime_type.dart';

/// A body type.
class BodyType {
  /// The mime type of the body.
  final MimeType mimeType;

  /// The encoding of the body.
  final Encoding? encoding;

  const BodyType({
    required this.mimeType,
    this.encoding,
  });

  /// Returns the value to use for the Content-Type header.
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
