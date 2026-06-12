import '../../primitives/header_scanner.dart';

/// Extracts the `report-to` parameter value from already-split (top-level,
/// quote-aware) `;` parameter segments (e.g. for COEP/COOP). Returns `null` if
/// absent. A quoted value is decoded as an RFC 9110 `quoted-string`, with its
/// `quoted-pair` escapes removed. The parameter name is matched
/// case-insensitively.
String? parseReportToParam(final Iterable<String> params) {
  for (final raw in params) {
    final p = raw.trim();
    final eq = p.indexOf('=');
    if (eq < 0) continue;
    if (p.substring(0, eq).trim().toLowerCase() != 'report-to') continue;
    final rest = p.substring(eq + 1).trim();
    if (!rest.startsWith('"')) return rest;
    // Decode through the canonical reader so quoted-pair escapes are handled
    // exactly as elsewhere, rather than a divergent hand-rolled unescape.
    final scanner = HeaderScanner(rest);
    final value = scanner.readQuotedString();
    scanner.skipOws();
    if (!scanner.atEnd) {
      throw FormatException(
        'unexpected characters after report-to value',
        rest,
      );
    }
    return value;
  }
  return null;
}

/// Renders a `report-to` parameter as `report-to="..."`, escaping interior
/// `"` and `\` as `quoted-pair` so the value round-trips through
/// [parseReportToParam].
String encodeReportToParam(final String value) {
  // Reject control characters (CR/LF in particular) rather than emitting them
  // verbatim inside the header, so untrusted input cannot split it.
  for (var i = 0; i < value.length; i++) {
    final c = value.codeUnitAt(i);
    if (c <= 0x1F || c == 0x7F) {
      throw const FormatException(
        'report-to value must not contain control characters',
      );
    }
  }
  final escaped = value.replaceAll(r'\', r'\\').replaceAll('"', r'\"');
  return 'report-to="$escaped"';
}
