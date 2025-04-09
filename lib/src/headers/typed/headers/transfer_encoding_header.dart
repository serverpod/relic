import 'package:collection/collection.dart';
import '../../../../relic.dart';
import '../../extension/string_list_extensions.dart';

/// A class representing the HTTP Transfer-Encoding header.
///
/// This class manages transfer encodings such as `chunked`, `compress`, `deflate`, and `gzip`.
/// It provides functionality to parse and generate transfer encoding header values.
final class TransferEncodingHeader {
  static const codec = HeaderCodec(TransferEncodingHeader.parse, __encode);
  static List<String> __encode(final TransferEncodingHeader value) =>
      [value._encode()];

  /// A list of transfer encodings.
  final List<TransferEncoding> encodings;

  /// Constructs a [TransferEncodingHeader] instance with the specified transfer encodings.
  TransferEncodingHeader({
    required final List<TransferEncoding> encodings,
  }) : encodings = _reorderEncodings(encodings);

  /// Parses the Transfer-Encoding header value and returns a [TransferEncodingHeader] instance.
  ///
  /// This method splits the value by commas and trims each encoding.
  factory TransferEncodingHeader.parse(final Iterable<String> values) {
    final splitValues = values.splitTrimAndFilterUnique();
    if (splitValues.isEmpty) {
      throw const FormatException('Value cannot be empty');
    }

    final encodings = splitValues.map(TransferEncoding.parse).toList();

    return TransferEncodingHeader(encodings: encodings);
  }

  /// Converts the [TransferEncodingHeader] instance into a string
  /// representation suitable for HTTP headers.
  String _encode() => encodings.map((final e) => e.name).join(', ');

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
    final List<TransferEncoding> encodings,
  ) {
    final TransferEncoding? chunked = encodings.firstWhereOrNull(
      (final e) => e.name == TransferEncoding.chunked.name,
    );
    if (chunked == null) return encodings;

    final reordered = List<TransferEncoding>.from(encodings);
    reordered.removeWhere((final e) => e.name == TransferEncoding.chunked.name);
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
  factory TransferEncoding.parse(final String name) {
    final trimmed = name.trim();
    if (trimmed.isEmpty) {
      throw const FormatException('Name cannot be empty');
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
        throw const FormatException('Invalid value');
    }
  }

  @override
  String toString() => name;
}
