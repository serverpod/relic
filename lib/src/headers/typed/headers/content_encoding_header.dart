import 'package:collection/collection.dart';

import '../../../../relic.dart';
import '../../extension/string_list_extensions.dart';

/// A class representing the HTTP Content-Encoding header.
///
/// This class manages content encodings such as `gzip`, `compress`, `deflate`,
/// `br`, and `identity`. It provides functionality to parse and generate
/// content encoding header values.
final class ContentEncodingHeader {
  static const codec = HeaderCodec(ContentEncodingHeader.parse, __encode);
  static List<String> __encode(final ContentEncodingHeader value) => [
    value._encode(),
  ];

  /// A list of content encodings.
  final List<ContentEncoding> encodings;

  /// Constructs a [ContentEncodingHeader] instance with the specified content
  /// encodings.
  ContentEncodingHeader.encodings(final List<ContentEncoding> encodings)
    : assert(encodings.isNotEmpty),
      encodings = List.unmodifiable(encodings);

  /// Parses the Content-Encoding header value and returns a
  /// [ContentEncodingHeader] instance.
  ///
  /// This method splits the value by commas and trims each encoding.
  factory ContentEncodingHeader.parse(final Iterable<String> values) {
    final splitValues = values.splitTrimAndFilterUnique();
    if (splitValues.isEmpty) {
      throw const FormatException('Value cannot be empty');
    }

    final parsedEncodings = splitValues
        .map((final e) => ContentEncoding.parse(e))
        .toList();

    return ContentEncodingHeader.encodings(parsedEncodings);
  }

  /// Checks if the Content-Encoding contains a specific encoding.
  bool containsEncoding(final ContentEncoding encoding) {
    return encodings.contains(encoding);
  }

  /// Converts the [ContentEncodingHeader] instance into a string representation
  /// suitable for HTTP headers.
  String _encode() => encodings.map((final e) => e.name).join(', ');

  @override
  bool operator ==(final Object other) =>
      identical(this, other) ||
      other is ContentEncodingHeader &&
          const ListEquality<ContentEncoding>().equals(
            encodings,
            other.encodings,
          );

  @override
  int get hashCode => const ListEquality<ContentEncoding>().hash(encodings);

  @override
  String toString() {
    return 'ContentEncodingHeader(encodings: $encodings)';
  }
}

/// A class representing valid content encodings.
class ContentEncoding {
  /// The string representation of the content encoding.
  final String name;

  /// Constructs a [ContentEncoding] instance with the specified name.
  const ContentEncoding._(this.name);

  /// Predefined content encodings.
  static const _gzip = 'gzip';
  static const _compress = 'compress';
  static const _deflate = 'deflate';
  static const _br = 'br';
  static const _identity = 'identity';
  static const _zstd = 'zstd';

  static const gzip = ContentEncoding._(_gzip);
  static const compress = ContentEncoding._(_compress);
  static const deflate = ContentEncoding._(_deflate);
  static const br = ContentEncoding._(_br);
  static const identity = ContentEncoding._(_identity);
  static const zstd = ContentEncoding._(_zstd);

  /// Parses a [name] and returns the corresponding [ContentEncoding] instance.
  /// If the name does not match any predefined encodings, it returns a custom
  /// instance.
  factory ContentEncoding.parse(final String name) {
    final trimmed = name.trim();
    if (trimmed.isEmpty) {
      throw const FormatException('Name cannot be empty');
    }
    switch (trimmed) {
      case _gzip:
        return gzip;
      case _compress:
        return compress;
      case _deflate:
        return deflate;
      case _br:
        return br;
      case _identity:
        return identity;
      case _zstd:
        return zstd;
      default:
        throw const FormatException('Invalid value');
    }
  }

  @override
  bool operator ==(final Object other) =>
      identical(this, other) || other is ContentEncoding && name == other.name;

  @override
  int get hashCode => name.hashCode;

  @override
  String toString() => 'ContentEncoding(name: $name)';
}
