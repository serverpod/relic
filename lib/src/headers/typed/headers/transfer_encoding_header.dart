import "package:relic/relic.dart";
import 'package:collection/collection.dart';
import 'package:relic/src/headers/extension/string_list_extensions.dart';

/// A class representing the HTTP Transfer-Encoding header.
///
/// This class manages transfer encodings such as `chunked`, `compress`, `deflate`, and `gzip`.
/// It provides functionality to parse and generate transfer encoding header values.
final class TransferEncodingHeader {
  static const codec = HeaderCodec(TransferEncodingHeader.parse, _encode);
  static List<String> _encode(TransferEncodingHeader value) =>
      [value.toHeaderString()];

  /// A list of transfer encodings.
  final List<TransferEncoding> encodings;

  /// Constructs a [TransferEncodingHeader] instance with the specified transfer encodings.
  TransferEncodingHeader({
    required List<TransferEncoding> encodings,
  }) : encodings = _reorderEncodings(encodings);

  /// Parses the Transfer-Encoding header value and returns a [TransferEncodingHeader] instance.
  ///
  /// This method splits the value by commas and trims each encoding.
  factory TransferEncodingHeader.parse(Iterable<String> values) {
    var splitValues = values.splitTrimAndFilterUnique();
    if (splitValues.isEmpty) {
      throw FormatException('Value cannot be empty');
    }

    var encodings = splitValues.map(TransferEncoding.parse).toList();

    return TransferEncodingHeader(encodings: encodings);
  }

  /// Converts the [TransferEncodingHeader] instance into a string
  /// representation suitable for HTTP headers.
  String toHeaderString() => encodings.map((e) => e.name).join(', ');

  @override
  String toString() {
    return 'TransferEncodingHeader(encodings: $encodings)';
  }

  /// Ensures that the 'chunked' transfer encoding is always the last in the list.
  ///
  /// According to the HTTP/1.1 specification (RFC 9112), the 'chunked' transfer
  /// encoding must be the final encoding applied to the response body. This is
  /// because 'chunked' signals the end of the response message, and any
  /// encoding after 'chunked' would cause ambiguity or violate the standard.
  ///
  /// Example of valid ordering:
  ///   Transfer-Encoding: gzip, chunked
  ///
  /// Example of invalid ordering:
  ///   Transfer-Encoding: chunked, gzip
  ///
  /// This function reorders the encodings to comply with the standard and
  /// ensures compatibility with HTTP clients and intermediaries.
  static List<TransferEncoding> _reorderEncodings(
    List<TransferEncoding> encodings,
  ) {
    final TransferEncoding? chunked = encodings.firstWhereOrNull(
      (e) => e.name == TransferEncoding.chunked.name,
    );
    if (chunked == null) return encodings;

    var reordered = List<TransferEncoding>.from(encodings);
    reordered.removeWhere((e) => e.name == TransferEncoding.chunked.name);
    reordered.add(chunked);
    return reordered;
  }
}

/// A class representing valid transfer encodings.
class TransferEncoding {
  /// The string representation of the transfer encoding.
  final String name;

  /// Constructs a [TransferEncoding] instance with the specified name.
  const TransferEncoding._(this.name);

  /// Predefined transfer encodings.
  static const _identity = 'identity';
  static const _chunked = 'chunked';
  static const _compress = 'compress';
  static const _deflate = 'deflate';
  static const _gzip = 'gzip';

  static const identity = TransferEncoding._(_identity);
  static const chunked = TransferEncoding._(_chunked);
  static const compress = TransferEncoding._(_compress);
  static const deflate = TransferEncoding._(_deflate);
  static const gzip = TransferEncoding._(_gzip);

  /// Parses a [name] and returns the corresponding [TransferEncoding] instance.
  /// If the name does not match any predefined encodings, it returns a custom instance.
  factory TransferEncoding.parse(String name) {
    final trimmed = name.trim();
    if (trimmed.isEmpty) {
      throw FormatException('Name cannot be empty');
    }
    switch (trimmed) {
      case _identity:
        return identity;
      case _chunked:
        return chunked;
      case _compress:
        return compress;
      case _deflate:
        return deflate;
      case _gzip:
        return gzip;
      default:
        throw FormatException('Invalid value');
    }
  }

  /// Returns the string representation of the transfer encoding.
  String toHeaderString() => name;

  @override
  String toString() => name;
}
