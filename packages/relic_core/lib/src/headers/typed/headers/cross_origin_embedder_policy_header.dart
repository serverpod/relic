import '../../../../relic_core.dart';
import 'util/report_to.dart';

const int _semicolon = 0x3B;

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

  /// The optional `report-to` reporting endpoint, if present.
  final String? reportTo;

  /// Constructs a [CrossOriginEmbedderPolicyHeader] instance with the specified value.
  const CrossOriginEmbedderPolicyHeader._(this.policy, [this.reportTo]);

  /// Predefined policy values.
  static const _unsafeNone = 'unsafe-none';
  static const _requireCorp = 'require-corp';
  static const _credentialless = 'credentialless';

  static const unsafeNone = CrossOriginEmbedderPolicyHeader._(_unsafeNone);
  static const requireCorp = CrossOriginEmbedderPolicyHeader._(_requireCorp);
  static const credentialless = CrossOriginEmbedderPolicyHeader._(
    _credentialless,
  );

  static const _known = {_unsafeNone, _requireCorp, _credentialless};

  /// Parses a [value] into a [CrossOriginEmbedderPolicyHeader].
  ///
  /// The value is the policy token optionally followed by parameters, e.g.
  /// `require-corp; report-to="endpoint"`. The `report-to` parameter is
  /// captured; an unknown policy token is rejected.
  factory CrossOriginEmbedderPolicyHeader.parse(final String value) {
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
    return CrossOriginEmbedderPolicyHeader._(token, reportTo);
  }

  /// Converts the [CrossOriginEmbedderPolicyHeader] instance into a string
  /// representation suitable for HTTP headers.

  String _encode() =>
      reportTo == null ? policy : '$policy; ${encodeReportToParam(reportTo!)}';

  @override
  bool operator ==(final Object other) =>
      identical(this, other) ||
      other is CrossOriginEmbedderPolicyHeader &&
          policy == other.policy &&
          reportTo == other.reportTo;

  @override
  int get hashCode => Object.hash(policy, reportTo);

  @override
  String toString() {
    return 'CrossOriginEmbedderPolicyHeader(value: $policy)';
  }
}
