import 'package:collection/collection.dart';
import '../../../../relic_core.dart';
import '../../extension/string_list_extensions.dart';

/// A class representing the HTTP Transfer-Encoding header.
///
/// This class manages transfer encodings such as `chunked`, `compress`, `deflate`, and `gzip`.
/// It provides functionality to parse and generate transfer encoding header values.
final class TransferEncodingHeader {
  static const codec = HeaderCodec(TransferEncodingHeader.parse, __encode);
  static List<String> __encode(final TransferEncodingHeader value) => [
    value._encode(),
  ];

  /// A list of transfer encodings.
  final List<TransferEncoding> encodings;

  /// Constructs a [TransferEncodingHeader] instance with the specified transfer encodings.
  ///
  /// Per RFC 9112 6.1 the `chunked` transfer-coding, if present, MUST be the
  /// final coding. A list with `chunked` in any other position is rejected
  /// rather than silently reordered (which would misrepresent the actual body
  /// framing and hide caller bugs).
  TransferEncodingHeader.encodings(final List<TransferEncoding> encodings)
    : encodings = List.unmodifiable(encodings) {
    if (encodings.isEmpty) {
      throw ArgumentError.value(encodings, 'encodings', 'cannot be empty');
    }
    final chunkedIndex = encodings.indexWhere(
      (final e) => e.name == TransferEncoding.chunked.name,
    );
    if (chunkedIndex >= 0 && chunkedIndex != encodings.length - 1) {
      throw const FormatException(
        'chunked transfer-coding must be the final coding (RFC 9112 6.1)',
      );
    }
  }

  /// Parses the Transfer-Encoding header value and returns a [TransferEncodingHeader] instance.
  ///
  /// This method splits the value by commas and trims each encoding.
  factory TransferEncodingHeader.parse(final Iterable<String> values) {
    final splitValues = values.splitTrimAndFilterUnique();
    if (splitValues.isEmpty) {
      throw const FormatException('Value cannot be empty');
    }

    // Deduplicate by canonical (case-insensitive) coding name, since
    // splitTrimAndFilterUnique only removes exact-string duplicates. Without
    // this, `chunked, CHUNKED` would keep both and then fail the
    // chunked-must-be-last check even though they are the same coding.
    final encodings = <TransferEncoding>[];
    final seen = <String>{};
    for (final raw in splitValues) {
      final encoding = TransferEncoding.parse(raw);
      if (seen.add(encoding.name)) {
        encodings.add(encoding);
      }
    }

    return TransferEncodingHeader.encodings(encodings);
  }

  /// Converts the [TransferEncodingHeader] instance into a string
  /// representation suitable for HTTP headers.
  String _encode() => encodings.map((final e) => e.name).join(', ');

  @override
  bool operator ==(final Object other) {
    if (identical(this, other)) return true;
    if (other is! TransferEncodingHeader) return false;
    return const ListEquality<TransferEncoding>().equals(
      encodings,
      other.encodings,
    );
  }

  @override
  int get hashCode => const ListEquality<TransferEncoding>().hash(encodings);

  @override
  String toString() {
    return 'TransferEncodingHeader(encodings: $encodings)';
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
  ///
  /// Transfer-codings are case-insensitive (RFC 9112 7), so the name is
  /// matched case-insensitively against the registered codings.
  factory TransferEncoding.parse(final String name) {
    final trimmed = name.trim();
    if (trimmed.isEmpty) {
      throw const FormatException('Name cannot be empty');
    }
    switch (trimmed.toLowerCase()) {
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
