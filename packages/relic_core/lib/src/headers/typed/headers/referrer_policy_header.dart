import '../../../../relic_core.dart';

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

  static const Map<String, ReferrerPolicyHeader> _byName = {
    _noReferrer: noReferrer,
    _noReferrerWhenDowngrade: noReferrerWhenDowngrade,
    _origin: origin,
    _originWhenCrossOrigin: originWhenCrossOrigin,
    _sameOrigin: sameOrigin,
    _strictOrigin: strictOrigin,
    _strictOriginWhenCrossOrigin: strictOriginWhenCrossOrigin,
    _unsafeUrl: unsafeUrl,
  };

  /// Parses a Referrer-Policy header value.
  ///
  /// Per the W3C Referrer Policy spec, the value is a comma-separated list of
  /// policy tokens processed left-to-right, keeping the last one the user
  /// agent recognizes (so a deployment can list `no-referrer, strict-origin`
  /// as a fallback for older agents). Unknown tokens are ignored, and the
  /// match is case-insensitive.
  factory ReferrerPolicyHeader.parse(final String value) {
    if (value.trim().isEmpty) {
      throw const FormatException('Value cannot be empty');
    }

    ReferrerPolicyHeader? lastValid;
    for (final token in value.split(',')) {
      final policy = _byName[token.trim().toLowerCase()];
      if (policy != null) lastValid = policy;
    }

    if (lastValid == null) {
      throw const FormatException('No valid referrer policy directive');
    }
    return lastValid;
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
