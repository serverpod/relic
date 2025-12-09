import '../../../../relic.dart';

/// A class representing the HTTP Cross-Origin-Opener-Policy header.
///
/// This header specifies the policy for opening cross-origin resources.
final class CrossOriginOpenerPolicyHeader {
  static const codec = HeaderCodec.single(
    CrossOriginOpenerPolicyHeader.parse,
    __encode,
  );
  static List<String> __encode(final CrossOriginOpenerPolicyHeader value) => [
    value._encode(),
  ];

  /// The policy value of the header.
  final String policy;

  /// Constructs a [CrossOriginOpenerPolicyHeader] instance with the specified value.
  const CrossOriginOpenerPolicyHeader._(this.policy);

  /// Predefined policy values.
  static const _sameOrigin = 'same-origin';
  static const _sameOriginAllowPopups = 'same-origin-allow-popups';
  static const _unsafeNone = 'unsafe-none';

  static const sameOrigin = CrossOriginOpenerPolicyHeader._(_sameOrigin);
  static const sameOriginAllowPopups = CrossOriginOpenerPolicyHeader._(
    _sameOriginAllowPopups,
  );
  static const unsafeNone = CrossOriginOpenerPolicyHeader._(_unsafeNone);

  /// Parses a [value] and returns the corresponding [CrossOriginOpenerPolicyHeader] instance.
  /// If the value does not match any predefined types, it returns a custom instance.
  factory CrossOriginOpenerPolicyHeader.parse(final String value) {
    final trimmed = value.trim();
    if (trimmed.isEmpty) {
      throw const FormatException('Value cannot be empty');
    }

    switch (trimmed) {
      case _sameOrigin:
        return sameOrigin;
      case _sameOriginAllowPopups:
        return sameOriginAllowPopups;
      case _unsafeNone:
        return unsafeNone;
      default:
        throw const FormatException('Invalid value');
    }
  }

  /// Converts the [CrossOriginOpenerPolicyHeader] instance into a string
  /// representation suitable for HTTP headers.

  String _encode() => policy;

  @override
  bool operator ==(final Object other) =>
      identical(this, other) ||
      other is CrossOriginOpenerPolicyHeader && policy == other.policy;

  @override
  int get hashCode => policy.hashCode;

  @override
  String toString() {
    return 'CrossOriginOpenerPolicyHeader(value: $policy)';
  }
}
