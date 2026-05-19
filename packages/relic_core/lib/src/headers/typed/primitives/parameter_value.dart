import 'package:meta/meta.dart';

import 'header_scanner.dart';
import 'token.dart';

/// A parameter value for the `token / quoted-string` alternation used
/// pervasively in HTTP headers (RFC 9110 5.6.6: `parameters`).
///
/// On the wire a parameter value is either a bare `token` (no quoting,
/// limited to `tchar`) or a `quoted-string` (DQUOTE-wrapped, with `\` escapes
/// for interior `"` and `\`).
///
/// Internally a [ParameterValue] always carries the unescaped value. On
/// [encode] the bare-token form is chosen when [value] is a valid token, and
/// the `quoted-string` form is chosen otherwise, with the necessary
/// `quoted-pair` escapes applied automatically.
@immutable
final class ParameterValue {
  /// The unescaped parameter value bytes (as a Dart [String]).
  final String value;

  /// Creates a [ParameterValue].
  ///
  /// Throws [FormatException] if [value] contains a character that cannot
  /// appear inside either a `token` or a `quoted-string` (i.e. CTL bytes
  /// other than HTAB, or code units beyond `0xFF`).
  ParameterValue(this.value) {
    for (var i = 0; i < value.length; i++) {
      if (!_isLegalInQuotedString(value.codeUnitAt(i))) {
        throw FormatException(
          'character not representable as token or quoted-string body',
          value,
          i,
        );
      }
    }
  }

  /// Reads a parameter value from [scanner]'s current position.
  ///
  /// Equivalent to [HeaderScanner.readTokenOrQuotedString] but returns a
  /// [ParameterValue] wrapper.
  factory ParameterValue.read(final HeaderScanner scanner) {
    return ParameterValue(scanner.readTokenOrQuotedString());
  }

  /// Returns the wire form: bare token when [value] is a valid token,
  /// otherwise a `quoted-string` with `"` and `\` escaped.
  String encode() {
    if (Token.isValid(value)) return value;
    return _quote(value);
  }

  @override
  bool operator ==(final Object other) =>
      identical(this, other) ||
      (other is ParameterValue && value == other.value);

  @override
  int get hashCode => value.hashCode;

  @override
  String toString() => encode();
}

String _quote(final String s) {
  final buf = StringBuffer()..writeCharCode(0x22);
  for (var i = 0; i < s.length; i++) {
    final c = s.codeUnitAt(i);
    if (c == 0x22 || c == 0x5C) buf.writeCharCode(0x5C);
    buf.writeCharCode(c);
  }
  buf.writeCharCode(0x22);
  return buf.toString();
}

bool _isLegalInQuotedString(final int c) {
  if (c == 0x09) return true; // HTAB
  if (c >= 0x20 && c <= 0x7E) return true; // SP + VCHAR
  if (c >= 0x80 && c <= 0xFF) return true; // obs-text
  return false;
}
