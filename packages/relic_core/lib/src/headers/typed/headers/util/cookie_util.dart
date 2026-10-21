import 'dart:typed_data';

/// Validates the cookie name and returns a string representation of the cookie name.
String validateCookieName(final String name) {
  for (int i = 0; i < name.length; i++) {
    if (!isCookieNameChar(name.codeUnitAt(i))) {
      throw const FormatException('Invalid cookie name');
    }
  }
  return name;
}

/// Whether [codeUnit] may appear in a cookie name.
///
/// A token character of RFC 6265 4.1.1, visible ASCII less the separators.
bool isCookieNameChar(final int codeUnit) =>
    codeUnit < 0x80 && _asciiClasses[codeUnit] & _nameChar != 0;

/// Whether [codeUnit] is a cookie-octet of RFC 6265 4.1.1, visible ASCII
/// less double quote, comma, semicolon and backslash.
bool isCookieOctet(final int codeUnit) =>
    codeUnit < 0x80 && _asciiClasses[codeUnit] & _octet != 0;

const _octet = 1;
const _nameChar = 2;

/// The class bits of every ASCII code unit.
///
/// A scan over a header value then does one load per character instead of
/// the range checks below that define the classes.
final Uint8List _asciiClasses = Uint8List.fromList([
  for (var c = 0; c < 0x80; c++)
    (_isCookieOctet(c) ? _octet : 0) | (_isCookieNameChar(c) ? _nameChar : 0),
]);

bool _isCookieNameChar(final int codeUnit) {
  if (codeUnit <= 0x20 || codeUnit >= 0x7F) return false;
  return switch (codeUnit) {
    0x28 || // (
    0x29 || // )
    0x3C || // <
    0x3E || // >
    0x40 || // @
    0x2C || // ,
    0x3B || // ;
    0x3A || // :
    0x5C || // backslash
    0x22 || // "
    0x2F || // /
    0x5B || // [
    0x5D || // ]
    0x3F || // ?
    0x3D || // =
    0x7B || // {
    0x7D => false, // }
    _ => true,
  };
}

/// Validates the cookie value and returns a string representation of the cookie value.
String validateCookieValue(final String value) {
  if (!isCookieValue(value, 0, value.length)) {
    throw const FormatException('Invalid cookie value');
  }
  // Cookie values are an opaque octet string per RFC 6265; servers MUST NOT
  // percent-decode them. Any URL encoding is an application-level convention
  // and should be applied/reversed by the application, not the parser.
  return value;
}

/// Whether `text[start..end)` is a cookie-value of RFC 6265 4.1.1,
/// cookie-octets optionally inside one pair of double quotes.
bool isCookieValue(final String text, int start, int end) {
  if (end - start >= 2 &&
      text.codeUnitAt(start) == 0x22 &&
      text.codeUnitAt(end - 1) == 0x22) {
    start++;
    end--;
  }
  final classes = _asciiClasses;
  for (int i = start; i < end; i++) {
    final codeUnit = text.codeUnitAt(i);
    if (codeUnit >= 0x80 || classes[codeUnit] & _octet == 0) return false;
  }
  return true;
}

/// Whether `text[start..end)` is a non-empty cookie-name of RFC 6265 4.1.1.
bool isCookieName(final String text, final int start, final int end) {
  if (start >= end) return false;
  final classes = _asciiClasses;
  for (int i = start; i < end; i++) {
    final codeUnit = text.codeUnitAt(i);
    if (codeUnit >= 0x80 || classes[codeUnit] & _nameChar == 0) return false;
  }
  return true;
}

bool _isCookieOctet(final int codeUnit) =>
    codeUnit == 0x21 ||
    (codeUnit >= 0x23 && codeUnit <= 0x2B) ||
    (codeUnit >= 0x2D && codeUnit <= 0x3A) ||
    (codeUnit >= 0x3C && codeUnit <= 0x5B) ||
    (codeUnit >= 0x5D && codeUnit <= 0x7E);

/// Whether [codeUnit] is one of the characters `String.trim` strips.
bool isTrimWhitespace(final int codeUnit) =>
    codeUnit == 0x20 ||
    (codeUnit >= 0x09 && codeUnit <= 0x0D) ||
    codeUnit == 0x85 ||
    codeUnit == 0xA0 ||
    codeUnit == 0x1680 ||
    (codeUnit >= 0x2000 && codeUnit <= 0x200A) ||
    codeUnit == 0x2028 ||
    codeUnit == 0x2029 ||
    codeUnit == 0x202F ||
    codeUnit == 0x205F ||
    codeUnit == 0x3000 ||
    codeUnit == 0xFEFF;

/// Validates a Set-Cookie `Path` (or `Domain` path-style) attribute value and
/// returns it unchanged.
///
/// Per RFC 6265 5.2.4 a path-value is `*av-octet` where `av-octet` is any
/// CHAR except CTLs or `;`. Rejecting control characters here prevents
/// header injection (CR/LF) when a path is built from untrusted input and
/// later serialized.
String validateCookiePath(final String path) {
  for (int i = 0; i < path.length; i++) {
    final int codeUnit = path.codeUnitAt(i);
    // CTLs (0x00-0x1F, 0x7F) and ';' (0x3B) are not allowed in a path-value.
    if (codeUnit <= 0x1F || codeUnit == 0x7F || codeUnit == 0x3B) {
      throw const FormatException('Invalid cookie path');
    }
  }
  return path;
}
