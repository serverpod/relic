import 'dart:convert';

import '../../headers/typed/headers/content_type_header.dart';
import '../../headers/typed/primitives/parameter_value.dart';
import '../../headers/typed/primitives/token.dart';
import 'mime_type.dart';

/// A body type that combines MIME type and encoding information.
///
/// This class encapsulates both the MIME type (what kind of content this is)
/// and the optional encoding (how text content is encoded into bytes).
///
/// Examples:
/// ```dart
/// // Text content with encoding
/// final textType = BodyType(
///   mimeType: MimeType.plainText,
///   encoding: utf8,
/// );
/// print(textType.toHeaderValue()); // "text/plain; charset=utf-8"
///
/// // Binary content without encoding
/// final binaryType = BodyType(mimeType: MimeType.octetStream);
/// print(binaryType.toHeaderValue()); // "application/octet-stream"
///
/// // JSON content
/// final jsonType = BodyType(
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

  /// Media type parameters other than `charset`, such as `boundary`.
  ///
  /// Keys are lowercase.
  final Map<String, String> parameters;

  /// Creates a [BodyType].
  ///
  /// Lowercases the names in [parameters]. Throws [ArgumentError] if
  /// [parameters] has a `charset`, which [encoding] sets.
  BodyType({
    required this.mimeType,
    this.encoding,
    final Map<String, String> parameters = const {},
  }) : parameters = parameters.isEmpty
           ? const {}
           : Map.unmodifiable(_normalizeParameters(parameters));

  /// The type of a body sent with [contentType].
  ///
  /// The `charset` parameter is the [encoding], and a text type without one
  /// is UTF-8. A parameter relic could not write back is dropped. For a
  /// request's Content-Type and an upstream response's alike.
  factory BodyType.fromContentType(final ContentTypeHeader contentType) {
    final mimeType = contentType.mimeType;
    final given = contentType.parameters;
    return BodyType(
      mimeType: mimeType,
      encoding:
          Encoding.getByName(contentType.charset) ??
          (mimeType.isText ? utf8 : null),
      parameters: given.isEmpty
          ? const {}
          : {
              for (final MapEntry(:key, :value) in given.entries)
                if (key != 'charset' && _isWritable(key, value)) key: value,
            },
    );
  }

  /// Returns the value of the parameter [name], matched case-insensitively.
  String? parameter(final String name) => parameters[name.toLowerCase()];

  /// Checks that the mime type and every parameter fit in a Content-Type
  /// header.
  ///
  /// Throws [FormatException] if one does not.
  void validate() {
    // Building the header value runs the same checks and keeps the value,
    // so a type that has one has passed them.
    if (_headerValue != null) return;
    mimeType.validate();
    for (final MapEntry(:key, :value) in parameters.entries) {
      Token.validate(key);
      ParameterValue(value);
    }
  }

  String? _headerValue;

  /// The value to use for the Content-Type header, built once per instance.
  ///
  /// Writes [encoding] as the `charset` parameter, then each entry of
  /// [parameters], separated by `; `. Throws [FormatException] where
  /// [validate] would.
  ///
  /// Examples:
  /// ```dart
  /// final bodyType = BodyType(mimeType: MimeType.plainText, encoding: utf8);
  /// print(bodyType.toHeaderValue()); // "text/plain; charset=utf-8"
  ///
  /// final binaryType = BodyType(mimeType: MimeType.octetStream);
  /// print(binaryType.toHeaderValue()); // "application/octet-stream"
  /// ```
  String toHeaderValue() => _headerValue ??= _buildHeaderValue();

  String _buildHeaderValue() {
    final charset = encoding;
    if (parameters.isEmpty) {
      final type = mimeType.toHeaderValue();
      return charset == null ? type : '$type; charset=${charset.name}';
    }
    return [
      mimeType.toHeaderValue(),
      if (charset != null) 'charset=${charset.name}',
      for (final MapEntry(:key, :value) in parameters.entries)
        '${Token.validate(key)}=${ParameterValue(value).encode()}',
    ].join('; ');
  }

  @override
  String toString() =>
      'BodyType(mimeType: $mimeType, encoding: $encoding, '
      'parameters: $parameters)';
}

bool _isWritable(final String name, final String value) {
  if (!Token.isValid(name)) return false;
  try {
    ParameterValue(value);
    return true;
  } on FormatException {
    return false;
  }
}

Map<String, String> _normalizeParameters(final Map<String, String> parameters) {
  final normalized = {
    for (final MapEntry(:key, :value) in parameters.entries)
      key.toLowerCase(): value,
  };
  if (normalized.containsKey('charset')) {
    throw ArgumentError.value(
      parameters,
      'parameters',
      'Use encoding to set the charset',
    );
  }
  return normalized;
}
