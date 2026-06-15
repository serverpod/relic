import '../../../../relic_core.dart';

/// A class representing the HTTP ETag header.
///
/// This class manages the ETag value, which can be either strong or weak.
/// It provides functionality to parse the header value and construct the
/// appropriate header string.
final class ETagHeader {
  static const codec = HeaderCodec.single(ETagHeader.parse, __encode);
  static List<String> __encode(final ETagHeader value) => [value._encode()];

  /// The opaque-tag value, without the surrounding quotes.
  final String value;

  /// Indicates whether the ETag is weak.
  final bool isWeak;

  /// Constructs an [ETagHeader] instance with the specified value and whether it is weak.
  const ETagHeader({required this.value, this.isWeak = false});

  /// Predefined ETag prefixes.
  static const _weakPrefix = 'W/';
  static const _quote = '"';

  /// Checks whether [value] is a well-formed entity-tag (strong or weak) with a
  /// valid `etagc` opaque-tag (RFC 9110 8.8.3).
  ///
  /// Returns false (rather than throwing) for any malformed input, including
  /// empty, so callers can use it to distinguish an ETag from, e.g., an
  /// HTTP-date in `If-Range`.
  static bool isValidETag(final String value) {
    final trimmed = value.trim();
    if (trimmed.isEmpty) return false;
    try {
      ETagValue.parse(trimmed);
      return true;
    } on FormatException {
      return false;
    }
  }

  /// Parses the ETag header value and returns an [ETagHeader] instance.
  ///
  /// Delegates to the [ETagValue] primitive, which enforces the `etagc` grammar
  /// (RFC 9110 8.8.3): the opaque-tag is taken from between the quotes without
  /// stripping interior quotes, an interior `"` or CTL is rejected, and no
  /// whitespace is allowed between `W/` and the opening quote.
  factory ETagHeader.parse(final String value) {
    final trimmed = value.trim();
    if (trimmed.isEmpty) {
      throw const FormatException('Value cannot be empty');
    }
    final ETagValue etag;
    try {
      etag = ETagValue.parse(trimmed);
    } on FormatException {
      throw const FormatException('Invalid format');
    }
    return ETagHeader(value: etag.value, isWeak: etag.isWeak);
  }

  /// Converts the [ETagHeader] instance into a string representation suitable
  /// for HTTP headers.
  String _encode() {
    final prefix = isWeak ? _weakPrefix : '';
    return '$prefix$_quote$value$_quote';
  }

  @override
  bool operator ==(final Object other) =>
      identical(this, other) ||
      other is ETagHeader && value == other.value && isWeak == other.isWeak;

  @override
  int get hashCode => Object.hash(value, isWeak);

  @override
  String toString() {
    return 'ETagHeader(value: $value, isWeak: $isWeak)';
  }
}

// This class should be hidden on public export
extension InternalEx on ETagHeader {
  String encode() => _encode();
}
