import '../../../../relic.dart';

/// A class representing the HTTP Cross-Origin-Resource-Policy header.
///
/// This header specifies the policy for sharing resources across origins.
final class CrossOriginResourcePolicyHeader {
  static const codec =
      HeaderCodec.single(CrossOriginResourcePolicyHeader.parse, __encode);
  static List<String> __encode(final CrossOriginResourcePolicyHeader value) =>
      [value._encode()];

  /// The policy value of the header.
  final String policy;

  /// Constructs a [CrossOriginResourcePolicyHeader] instance with the specified value.
  const CrossOriginResourcePolicyHeader._(this.policy);

  /// Predefined policy values.
  static const _sameOrigin = 'same-origin';
  static const _sameSite = 'same-site';
  static const _crossOrigin = 'cross-origin';

  static const sameOrigin = CrossOriginResourcePolicyHeader._(_sameOrigin);
  static const sameSite = CrossOriginResourcePolicyHeader._(_sameSite);
  static const crossOrigin = CrossOriginResourcePolicyHeader._(_crossOrigin);

  /// Parses a [value] and returns the corresponding [CrossOriginResourcePolicyHeader] instance.
  /// If the value does not match any predefined types, it returns a custom instance.
  factory CrossOriginResourcePolicyHeader.parse(final String value) {
    final trimmed = value.trim();
    if (trimmed.isEmpty) {
      throw const FormatException('Value cannot be empty');
    }
    switch (trimmed) {
      case _sameOrigin:
        return sameOrigin;
      case _sameSite:
        return sameSite;
      case _crossOrigin:
        return crossOrigin;
      default:
        throw const FormatException('Invalid value');
    }
  }

  /// Converts the [CrossOriginResourcePolicyHeader] instance into a string
  /// representation suitable for HTTP headers.

  String _encode() => policy;

  @override
  bool operator ==(final Object other) =>
      identical(this, other) ||
      other is CrossOriginResourcePolicyHeader && policy == other.policy;

  @override
  int get hashCode => policy.hashCode;

  @override
  String toString() {
    return 'CrossOriginResourcePolicyHeader(value: $policy)';
  }
}
