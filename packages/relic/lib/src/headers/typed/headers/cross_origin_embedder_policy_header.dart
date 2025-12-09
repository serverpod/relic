import '../../../../relic.dart';

/// A class representing the HTTP Cross-Origin-Embedder-Policy header.
///
/// This header specifies the policy for embedding cross-origin resources.
final class CrossOriginEmbedderPolicyHeader {
  static const codec = HeaderCodec.single(
    CrossOriginEmbedderPolicyHeader.parse,
    __encode,
  );
  static List<String> __encode(final CrossOriginEmbedderPolicyHeader value) => [
    value._encode(),
  ];

  /// The policy value of the header.
  final String policy;

  /// Constructs a [CrossOriginEmbedderPolicyHeader] instance with the specified value.
  const CrossOriginEmbedderPolicyHeader._(this.policy);

  /// Predefined policy values.
  static const _unsafeNone = 'unsafe-none';
  static const _requireCorp = 'require-corp';
  static const _credentialless = 'credentialless';

  static const unsafeNone = CrossOriginEmbedderPolicyHeader._(_unsafeNone);
  static const requireCorp = CrossOriginEmbedderPolicyHeader._(_requireCorp);
  static const credentialless = CrossOriginEmbedderPolicyHeader._(
    _credentialless,
  );

  /// Parses a [value] and returns the corresponding [CrossOriginEmbedderPolicyHeader] instance.
  /// If the value does not match any predefined types, it returns a custom instance.
  factory CrossOriginEmbedderPolicyHeader.parse(final String value) {
    final trimmed = value.trim();
    if (trimmed.isEmpty) {
      throw const FormatException('Value cannot be empty');
    }

    switch (trimmed) {
      case _unsafeNone:
        return unsafeNone;
      case _requireCorp:
        return requireCorp;
      case _credentialless:
        return credentialless;
      default:
        throw const FormatException('Invalid value');
    }
  }

  /// Converts the [CrossOriginEmbedderPolicyHeader] instance into a string
  /// representation suitable for HTTP headers.

  String _encode() => policy;

  @override
  bool operator ==(final Object other) =>
      identical(this, other) ||
      other is CrossOriginEmbedderPolicyHeader && policy == other.policy;

  @override
  int get hashCode => policy.hashCode;

  @override
  String toString() {
    return 'CrossOriginEmbedderPolicyHeader(value: $policy)';
  }
}
