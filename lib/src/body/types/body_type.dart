import 'dart:convert';

import 'mime_type.dart';

/// A body type.
class BodyType {
  /// A body type for plain text.
  static const plainText = BodyType(
    mimeType: MimeType.plainText,
    encoding: utf8,
  );

  /// A body type for HTML.
  static const html = BodyType(
    mimeType: MimeType.html,
    encoding: utf8,
  );

  /// A body type for CSS.
  static const css = BodyType(
    mimeType: MimeType.css,
    encoding: utf8,
  );

  /// A body type for CSV.
  static const csv = BodyType(
    mimeType: MimeType.csv,
    encoding: utf8,
  );

  /// A body type for JavaScript.
  static const javascript = BodyType(
    mimeType: MimeType.javascript,
    encoding: utf8,
  );

  /// A body type for JSON.
  static const json = BodyType(
    mimeType: MimeType.json,
    encoding: utf8,
  );

  /// A body type for XML.
  static const xml = BodyType(
    mimeType: MimeType.xml,
    encoding: utf8,
  );

  /// A body type for octet stream data.
  static const octetStream = BodyType(
    mimeType: MimeType.octetStream,
  );

  /// A body type for PDF.
  static const pdf = BodyType(
    mimeType: MimeType.pdf,
  );

  /// A body type for RTF.
  static const rtf = BodyType(
    mimeType: MimeType.rtf,
  );

  /// A body type for multipart form data.
  static const multipartFormData = BodyType(
    mimeType: MimeType.multipartFormData,
  );

  /// A body type for multipart byteranges.
  static const multipartByteranges = BodyType(
    mimeType: MimeType.multipartByteranges,
  );

  /// A body type for URL-encoded form data.
  static const urlEncoded = BodyType(
    mimeType: MimeType.urlEncoded,
  );

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
