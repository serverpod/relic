/// A MIME type representation for content type handling.
///
/// Provides constants for common MIME types and utilities for parsing and
/// working with MIME types.
///
/// ## Common Usage
///
/// ```dart
/// // Using predefined constants
/// Body.fromString('Hello', mimeType: MimeType.plainText)
/// Body.fromString('<h1>Title</h1>', mimeType: MimeType.html)
/// Body.fromString('{"key": "value"}', mimeType: MimeType.json)
/// ```
///
/// ## Parsing MIME Types
///
/// ```dart
/// // Parse from string
/// final mimeType = MimeType.parse('application/json');
/// print(mimeType.primaryType); // application
/// print(mimeType.subType);     // json
/// ```
///
/// ## Custom MIME Types
///
/// ```dart
/// // Create custom MIME type
/// final customType = MimeType('application', 'vnd.myapp.v1+json');
/// Body.fromString(data, mimeType: customType)
/// ```
///
/// ## Checking MIME Type Properties
///
/// ```dart
/// final type = MimeType.json;
/// print(type.isText);    // true (JSON is text-based)
/// print(type.toString()); // application/json
/// ```
class MimeType {
  /// Text mime types.
  static const plainText = MimeType('text', 'plain');

  /// HTML mime type.
  static const html = MimeType('text', 'html');

  /// CSS mime type.
  static const css = MimeType('text', 'css');

  /// CSV mime type.
  static const csv = MimeType('text', 'csv');

  /// JavaScript mime type.
  static const javascript = MimeType('text', 'javascript');

  /// JSON mime type.
  static const json = MimeType('application', 'json');

  /// XML mime type.
  static const xml = MimeType('application', 'xml');

  /// Binary mime type.
  static const octetStream = MimeType('application', 'octet-stream');

  /// PDF mime type.
  static const pdf = MimeType('application', 'pdf');

  /// RTF mime type.
  static const rtf = MimeType('application', 'rtf');

  /// Multipart form data mime type.
  static const multipartFormData = MimeType('multipart', 'form-data');

  /// Multipart byteranges mime type.
  static const multipartByteranges = MimeType('multipart', 'byteranges');

  /// URL-encoded form MIME type.
  static const urlEncoded = MimeType('application', 'x-www-form-urlencoded');

  /// The primary type of the mime type.
  final String primaryType;

  /// The sub type of the mime type.
  final String subType;

  /// Creates a new mime type.
  const MimeType(this.primaryType, this.subType);

  /// Parses a mime type from a string.
  /// It splits the string on the '/' character and expects exactly two parts.
  /// First part is the primary type, second is the sub type.
  /// If the string is not a valid mime type then a [FormatException] is thrown.
  factory MimeType.parse(final String type) {
    final parts = type.split('/');
    if (parts.length != 2) {
      throw FormatException('Invalid mime type $type');
    }

    final primaryType = parts[0].trim();
    final subType = parts[1].trim();

    if (primaryType.isEmpty || subType.isEmpty) {
      throw FormatException('Invalid mime type $type');
    }

    return MimeType(primaryType, subType);
  }

  /// Returns `true` if the mime type is text.
  bool get isText {
    if (primaryType == 'text') return true;
    if (primaryType == 'application') {
      final st = subType.toLowerCase();
      // Common text-like app types and structured syntax suffixes.
      return st == 'json' ||
          st == 'xml' ||
          st == 'javascript' ||
          st == 'x-www-form-urlencoded' ||
          st.endsWith('+json') ||
          st.endsWith('+xml');
    }
    return false;
  }

  /// Returns the value to use for the Content-Type header.
  String toHeaderValue() => '$primaryType/$subType';

  @override
  String toString() => 'MimeType(primaryType: $primaryType, subType: $subType)';

  @override
  bool operator ==(final Object other) {
    if (other is! MimeType) return false;
    return primaryType == other.primaryType && subType == other.subType;
  }

  @override
  int get hashCode => Object.hash(primaryType, subType);
}
