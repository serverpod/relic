import 'package:collection/collection.dart';
import 'package:http_parser/http_parser.dart' as http_parser;

import '../../../../relic_core.dart';

/// A class representing the HTTP Content-Type header.
final class ContentTypeHeader {
  static const codec = HeaderCodec.single(ContentTypeHeader.parse, __encode);
  static List<String> __encode(final ContentTypeHeader value) => [
    value._encode(),
  ];

  /// The media type without parameters.
  final MimeType mimeType;

  /// Parameters associated with the media type, such as `charset` or `boundary`.
  final Map<String, String> parameters;

  /// Constructs a [ContentTypeHeader] instance with the specified MIME type and
  /// parameters.
  ContentTypeHeader({
    required this.mimeType,
    final Map<String, String> parameters = const {},
  }) : parameters = Map.unmodifiable(_normalizeParameters(parameters));

  /// Parses the Content-Type header value and returns a [ContentTypeHeader].
  factory ContentTypeHeader.parse(final String value) {
    final mediaType = http_parser.MediaType.parse(value);
    return ContentTypeHeader(
      mimeType: MimeType(mediaType.type, mediaType.subtype),
      parameters: mediaType.parameters,
    );
  }

  /// The charset parameter, if present.
  String? get charset => parameter('charset');

  /// Returns the parameter value for [name], matched case-insensitively.
  String? parameter(final String name) => parameters[name.toLowerCase()];

  /// Converts the [ContentTypeHeader] instance into a string representation
  /// suitable for HTTP headers.
  String _encode() {
    mimeType.validate();
    for (final parameter in parameters.keys) {
      Token.validate(parameter);
    }
    return http_parser.MediaType(
      mimeType.primaryType,
      mimeType.subType,
      parameters,
    ).toString();
  }

  @override
  bool operator ==(final Object other) =>
      identical(this, other) ||
      other is ContentTypeHeader &&
          mimeType == other.mimeType &&
          const MapEquality<String, String>().equals(
            parameters,
            other.parameters,
          );

  @override
  int get hashCode => Object.hash(
    mimeType,
    const MapEquality<String, String>().hash(parameters),
  );

  @override
  String toString() {
    return 'ContentTypeHeader(mimeType: $mimeType, parameters: $parameters)';
  }
}

Map<String, String> _normalizeParameters(final Map<String, String> parameters) {
  return {
    for (final entry in parameters.entries)
      entry.key.toLowerCase(): entry.value,
  };
}
