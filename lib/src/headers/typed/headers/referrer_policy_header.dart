import '../../../../relic.dart';

/// A class representing the HTTP Referrer-Policy header.
///
/// This class manages the referrer policy, providing functionality to parse
/// and generate referrer policy header values.
final class ReferrerPolicyHeader {
  static const codec = HeaderCodec.single(ReferrerPolicyHeader.parse, __encode);
  static List<String> __encode(final ReferrerPolicyHeader value) => [
    value._encode(),
  ];

  /// The string representation of the referrer policy directive.
  final String directive;

  /// Private constructor for [ReferrerPolicyHeader].
  const ReferrerPolicyHeader._(this.directive);

  /// Predefined referrer policy directives.
  static const _noReferrer = 'no-referrer';
  static const _noReferrerWhenDowngrade = 'no-referrer-when-downgrade';
  static const _origin = 'origin';
  static const _originWhenCrossOrigin = 'origin-when-cross-origin';
  static const _sameOrigin = 'same-origin';
  static const _strictOrigin = 'strict-origin';
  static const _strictOriginWhenCrossOrigin = 'strict-origin-when-cross-origin';
  static const _unsafeUrl = 'unsafe-url';

  static const noReferrer = ReferrerPolicyHeader._(_noReferrer);
  static const noReferrerWhenDowngrade = ReferrerPolicyHeader._(
    _noReferrerWhenDowngrade,
  );
  static const origin = ReferrerPolicyHeader._(_origin);
  static const originWhenCrossOrigin = ReferrerPolicyHeader._(
    _originWhenCrossOrigin,
  );
  static const sameOrigin = ReferrerPolicyHeader._(_sameOrigin);
  static const strictOrigin = ReferrerPolicyHeader._(_strictOrigin);
  static const strictOriginWhenCrossOrigin = ReferrerPolicyHeader._(
    _strictOriginWhenCrossOrigin,
  );
  static const unsafeUrl = ReferrerPolicyHeader._(_unsafeUrl);

  /// Parses a [directive] and returns the corresponding [ReferrerPolicyHeader] instance.
  /// If the directive does not match any predefined types, it returns a custom instance.
  factory ReferrerPolicyHeader.parse(final String value) {
    final trimmed = value.trim();
    if (trimmed.isEmpty) {
      throw const FormatException('Value cannot be empty');
    }

    switch (trimmed) {
      case _noReferrer:
        return noReferrer;
      case _noReferrerWhenDowngrade:
        return noReferrerWhenDowngrade;
      case _origin:
        return origin;
      case _originWhenCrossOrigin:
        return originWhenCrossOrigin;
      case _sameOrigin:
        return sameOrigin;
      case _strictOrigin:
        return strictOrigin;
      case _strictOriginWhenCrossOrigin:
        return strictOriginWhenCrossOrigin;
      case _unsafeUrl:
        return unsafeUrl;
      default:
        throw const FormatException('Invalid value');
    }
  }

  /// Converts the [ReferrerPolicyHeader] instance into a string
  /// representation suitable for HTTP headers.

  String _encode() => directive;

  @override
  bool operator ==(final Object other) =>
      identical(this, other) ||
      other is ReferrerPolicyHeader && directive == other.directive;

  @override
  int get hashCode => directive.hashCode;

  @override
  String toString() {
    return 'ReferrerPolicyHeader(directive: $directive)';
  }
}
