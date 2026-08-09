/// An HTTP `token68` value per [RFC 7235 section 2.1][rfc-token68].
///
///     token68 = 1*( ALPHA / DIGIT / "-" / "." / "_" / "~" / "+" / "/" )
///               *"="
///
/// The form carrying opaque credentials and challenges such as base64
/// payloads (`Basic`, `Bearer`, `Negotiate`). Its alphabet differs from the
/// `token` grammar: `+`, `/`, and trailing `=` padding are legal here while
/// most `tchar` specials are not, so the two forms need separate validators.
///
/// [rfc-token68]: https://datatracker.ietf.org/doc/html/rfc7235#section-2.1
abstract final class Token68 {
  /// True if [s] is a syntactically valid `token68` value: at least one
  /// character from the `token68` alphabet, followed only by `=` padding.
  static bool isValid(final String s) {
    var i = 0;
    while (i < s.length && _isToken68Char(s.codeUnitAt(i))) {
      i++;
    }
    if (i == 0) return false;
    while (i < s.length && s.codeUnitAt(i) == 0x3D) {
      i++;
    }
    return i == s.length;
  }

  /// Returns [s] unchanged if it is a valid `token68` value, otherwise throws
  /// [FormatException].
  static String validate(final String s) {
    if (!isValid(s)) {
      throw FormatException('Not a valid HTTP token68 (RFC 7235 2.1)', s);
    }
    return s;
  }
}

bool _isToken68Char(final int c) {
  // ALPHA
  if (c >= 0x41 && c <= 0x5A) return true; // A-Z
  if (c >= 0x61 && c <= 0x7A) return true; // a-z
  // DIGIT
  if (c >= 0x30 && c <= 0x39) return true; // 0-9
  // token68 specials: - . _ ~ + /
  switch (c) {
    case 0x2B:
    case 0x2D:
    case 0x2E:
    case 0x2F:
    case 0x5F:
    case 0x7E:
      return true;
  }
  return false;
}
