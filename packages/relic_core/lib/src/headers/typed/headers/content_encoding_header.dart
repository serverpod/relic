import 'dart:typed_data';

import 'package:collection/collection.dart';

import '../../../../relic_core.dart';
import '../primitives/byte_fields.dart';
import '../primitives/byte_scanner.dart' show latin1Bytes;

/// A class representing the HTTP Content-Encoding header.
///
/// This class manages content encodings such as `gzip`, `compress`, `deflate`,
/// `br`, and `identity`. It provides functionality to parse and generate
/// content encoding header values.
final class ContentEncodingHeader {
  static const codec = HeaderCodec.fields(_parseFields, __encode);
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
  factory ContentEncodingHeader.parse(final Iterable<String> values) =>
      _parseFields([for (final value in values) latin1Bytes(value)]);

  /// Takes [encodings], a list the parser built, as its own.
  const ContentEncodingHeader._(this.encodings);

  /// The header from the wire bytes of its [fields].
  static ContentEncodingHeader _parseFields(final List<Uint8List> fields) {
    final elements = splitFieldsUnique(fields);
    if (elements.isEmpty) {
      throw const FormatException('Value cannot be empty');
    }
    return ContentEncodingHeader._(
      List.generate(
        elements.length,
        (final i) => ContentEncoding._parseBytes(elements[i]),
        growable: false,
      ),
    );
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

  /// Parses a [name] into a [ContentEncoding].
  ///
  /// The set of content-codings is an open IANA registry (RFC 9110 8.4.1), so
  /// any valid `token` is accepted rather than only the predefined ones; this
  /// lets recipients pass through unknown codings instead of failing. Codings
  /// are case-insensitive, so the name is canonicalized to lowercase.
  factory ContentEncoding.parse(final String name) =>
      ContentEncoding._parseBytes(trimmed(latin1Bytes(name)));

  /// [parse] over the wire bytes of one trimmed element.
  static ContentEncoding _parseBytes(final Uint8List element) {
    if (element.isEmpty) {
      throw const FormatException('Name cannot be empty');
    }
    return ContentEncoding._(tokenText(element).toLowerCase());
  }

  @override
  bool operator ==(final Object other) =>
      identical(this, other) || other is ContentEncoding && name == other.name;

  @override
  int get hashCode => name.hashCode;

  @override
  String toString() => 'ContentEncoding(name: $name)';
}
