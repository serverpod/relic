import '../../../../relic_core.dart';

/// A class representing the HTTP Expect header.
///
/// This class manages the directive for the Expect header, such as `100-continue`.
/// It provides functionality to parse and generate Expect header values.
final class ExpectHeader {
  static const codec = HeaderCodec.single(ExpectHeader.parse, __encode);
  static List<String> __encode(final ExpectHeader value) => [value._encode()];

  /// The string representation of the expectation directive.
  final String value;

  /// Constructs an [ExpectHeader] instance with the specified value.
  const ExpectHeader._(this.value);

  /// Predefined expectation directives.
  static const _continue100 = '100-continue';

  static const continue100 = ExpectHeader._(_continue100);

  /// Parses a [value] and returns the corresponding [ExpectHeader] instance.
  ///
  /// Per RFC 9110 10.1.1 the only currently registered expectation is
  /// `100-continue`, but the spec requires recipients to preserve unknown
  /// expectations so a server can respond with `417 Expectation Failed`
  /// rather than failing at the parse step. The matching of the known
  /// `100-continue` token is case-insensitive.
  factory ExpectHeader.parse(final String value) {
    final trimmed = value.trim();
    if (trimmed.isEmpty) {
      throw const FormatException('Value cannot be empty');
    }
    if (trimmed.toLowerCase() == _continue100) {
      return continue100;
    }
    // Unknown expectations are preserved (so a server can answer 417), but
    // control characters are rejected so a CR/LF cannot be injected into the
    // header when the value is later re-emitted. HTAB (0x09) is legal OWS in a
    // field value and is allowed.
    for (var i = 0; i < trimmed.length; i++) {
      final c = trimmed.codeUnitAt(i);
      if ((c <= 0x1F && c != 0x09) || c == 0x7F) {
        throw const FormatException('Invalid value');
      }
    }
    return ExpectHeader._(trimmed);
  }

  /// Converts the [ExpectHeader] instance into a string representation
  /// suitable for HTTP headers.

  String _encode() => value;

  @override
  bool operator ==(final Object other) =>
      identical(this, other) || other is ExpectHeader && value == other.value;

  @override
  int get hashCode => value.hashCode;

  @override
  String toString() {
    return 'ExpectHeader(value: $value)';
  }
}
