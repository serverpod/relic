import "package:relic/relic.dart";

/// A class representing the HTTP Cross-Origin-Opener-Policy header.
///
/// This header specifies the policy for opening cross-origin resources.
final class CrossOriginOpenerPolicyHeader {
  static const codec =
      HeaderCodec.single(CrossOriginOpenerPolicyHeader.parse, encode);
  static List<String> encode(CrossOriginOpenerPolicyHeader value) =>
      [value.toHeaderString()];

  /// The policy value of the header.
  final String policy;

  /// Constructs a [CrossOriginOpenerPolicyHeader] instance with the specified value.
  const CrossOriginOpenerPolicyHeader._(this.policy);

  /// Predefined policy values.
  static const _sameOrigin = 'same-origin';
  static const _sameOriginAllowPopups = 'same-origin-allow-popups';
  static const _unsafeNone = 'unsafe-none';

  static const sameOrigin = CrossOriginOpenerPolicyHeader._(_sameOrigin);
  static const sameOriginAllowPopups =
      CrossOriginOpenerPolicyHeader._(_sameOriginAllowPopups);
  static const unsafeNone = CrossOriginOpenerPolicyHeader._(_unsafeNone);

  /// Parses a [value] and returns the corresponding [CrossOriginOpenerPolicyHeader] instance.
  /// If the value does not match any predefined types, it returns a custom instance.
  factory CrossOriginOpenerPolicyHeader.parse(String value) {
    final trimmed = value.trim();
    if (trimmed.isEmpty) {
      throw FormatException('Value cannot be empty');
    }

    switch (trimmed) {
      case _sameOrigin:
        return sameOrigin;
      case _sameOriginAllowPopups:
        return sameOriginAllowPopups;
      case _unsafeNone:
        return unsafeNone;
      default:
        throw FormatException('Invalid value');
    }
  }

  /// Converts the [CrossOriginOpenerPolicyHeader] instance into a string
  /// representation suitable for HTTP headers.

  String toHeaderString() => policy;

  @override
  String toString() {
    return 'CrossOriginOpenerPolicyHeader(value: $policy)';
  }
}
