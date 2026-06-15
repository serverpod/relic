import '../../../../relic_core.dart';
import 'util/report_to.dart';

const int _semicolon = 0x3B;

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

  /// The optional `report-to` reporting endpoint, if present.
  final String? reportTo;

  /// Constructs a [CrossOriginOpenerPolicyHeader] instance with the specified value.
  const CrossOriginOpenerPolicyHeader._(this.policy, [this.reportTo]);

  /// Predefined policy values.
  static const _sameOrigin = 'same-origin';
  static const _sameOriginAllowPopups = 'same-origin-allow-popups';
  static const _noopenerAllowPopups = 'noopener-allow-popups';
  static const _unsafeNone = 'unsafe-none';

  static const sameOrigin = CrossOriginOpenerPolicyHeader._(_sameOrigin);
  static const sameOriginAllowPopups = CrossOriginOpenerPolicyHeader._(
    _sameOriginAllowPopups,
  );
  static const noopenerAllowPopups = CrossOriginOpenerPolicyHeader._(
    _noopenerAllowPopups,
  );
  static const unsafeNone = CrossOriginOpenerPolicyHeader._(_unsafeNone);

  static const _known = {
    _sameOrigin,
    _sameOriginAllowPopups,
    _noopenerAllowPopups,
    _unsafeNone,
  };

  /// Parses a [value] into a [CrossOriginOpenerPolicyHeader].
  ///
  /// The value is the policy token optionally followed by parameters, e.g.
  /// `same-origin; report-to="endpoint"`. The `report-to` parameter is
  /// captured; an unknown policy token is rejected.
  factory CrossOriginOpenerPolicyHeader.parse(final String value) {
    if (value.trim().isEmpty) {
      throw const FormatException('Value cannot be empty');
    }
    // Split parameters at top-level ';' only, so a ';' inside a quoted
    // report-to value does not split the value.
    final parts = HeaderScanner(value).splitTopLevel(_semicolon).toList();
    final token = parts.first.trim().toLowerCase();
    if (!_known.contains(token)) {
      throw const FormatException('Invalid value');
    }
    final reportTo = parseReportToParam(parts.skip(1));
    return CrossOriginOpenerPolicyHeader._(token, reportTo);
  }

  /// Converts the [CrossOriginOpenerPolicyHeader] instance into a string
  /// representation suitable for HTTP headers.

  String _encode() =>
      reportTo == null ? policy : '$policy; ${encodeReportToParam(reportTo!)}';

  @override
  bool operator ==(final Object other) =>
      identical(this, other) ||
      other is CrossOriginOpenerPolicyHeader &&
          policy == other.policy &&
          reportTo == other.reportTo;

  @override
  int get hashCode => Object.hash(policy, reportTo);

  @override
  String toString() {
    return 'CrossOriginOpenerPolicyHeader(value: $policy)';
  }
}
