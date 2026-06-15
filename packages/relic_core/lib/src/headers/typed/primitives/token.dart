import 'package:meta/meta.dart';

/// An HTTP `token` value per [RFC 9110 section 5.6.2][rfc-token].
///
///     token  = 1*tchar
///     tchar  = "!" / "#" / "$" / "%" / "&" / "'" / "*" / "+" / "-"
///            / "." / "^" / "_" / "`" / "|" / "~" / DIGIT / ALPHA
///
/// Tokens are ASCII case-insensitive when compared as wire values
/// ([RFC 9110 section 5.6.2][rfc-token] and [section 11.1][rfc-scheme]).
///
/// This interface lets closed-by-spec enums (e.g. cache directive names) and
/// open-token-valued types (e.g. content codings) share the same parser and
/// encoder primitives. Concrete implementations supply a [value] string whose
/// characters MUST satisfy [Token.isValid].
///
/// Implementations may use either identity equality (natural for Dart enum
/// values) or ASCII case-insensitive value equality (suitable for free-form
/// implementors such as [TokenValue]). To compare two [Token]s by their wire
/// value regardless of how their [operator ==] is defined, use [Token.equals].
///
/// [rfc-token]: https://datatracker.ietf.org/doc/html/rfc9110#section-5.6.2
/// [rfc-scheme]: https://datatracker.ietf.org/doc/html/rfc9110#section-11.1
abstract interface class Token {
  /// The token characters as they appear on the wire.
  String get value;

  /// True if [s] is a syntactically valid token: non-empty and composed only
  /// of `tchar` characters.
  static bool isValid(final String s) {
    if (s.isEmpty) return false;
    for (var i = 0; i < s.length; i++) {
      if (!isTchar(s.codeUnitAt(i))) return false;
    }
    return true;
  }

  /// True if [c] is a single `tchar` code unit per RFC 9110 5.6.2.
  static bool isTchar(final int c) => _isTchar(c);

  /// Returns [s] unchanged if it is a valid token, otherwise throws
  /// [FormatException].
  static String validate(final String s) {
    if (!isValid(s)) {
      throw FormatException('Not a valid HTTP token (RFC 9110 5.6.2)', s);
    }
    return s;
  }

  /// ASCII case-insensitive equality of two token wire values.
  ///
  /// Use this when comparing tokens whose runtime types may differ (e.g. a
  /// [TokenValue] against an enum that `implements Token`).
  static bool equals(final Token a, final Token b) =>
      _ciEquals(a.value, b.value);

  /// Hash code consistent with [equals]: ASCII case-insensitive hash of
  /// [t]'s wire value.
  static int hashFor(final Token t) => _ciHash(t.value);
}

/// A free-form [Token] value, validated at construction.
///
/// Suitable for headers where the spec defines an open set of token values
/// (e.g. `Content-Encoding`, `Connection`). For closed value sets prefer a
/// dedicated `enum implements Token`.
///
/// [operator ==] and [hashCode] use ASCII case-insensitive value semantics, so
/// `TokenValue('gzip') == TokenValue('GZIP')` is `true`.
@immutable
final class TokenValue implements Token {
  @override
  final String value;

  /// Creates a [TokenValue], throwing [FormatException] if [value] is not a
  /// valid HTTP token per [Token.isValid].
  TokenValue(final String value) : value = Token.validate(value);

  @override
  bool operator ==(final Object other) =>
      identical(this, other) ||
      (other is TokenValue && _ciEquals(value, other.value));

  @override
  int get hashCode => _ciHash(value);

  @override
  String toString() => value;
}

bool _isTchar(final int c) {
  // ALPHA
  if (c >= 0x41 && c <= 0x5A) return true; // A-Z
  if (c >= 0x61 && c <= 0x7A) return true; // a-z
  // DIGIT
  if (c >= 0x30 && c <= 0x39) return true; // 0-9
  // tchar specials: ! # $ % & ' * + - . ^ _ ` | ~
  switch (c) {
    case 0x21:
    case 0x23:
    case 0x24:
    case 0x25:
    case 0x26:
    case 0x27:
    case 0x2A:
    case 0x2B:
    case 0x2D:
    case 0x2E:
    case 0x5E:
    case 0x5F:
    case 0x60:
    case 0x7C:
    case 0x7E:
      return true;
  }
  return false;
}

bool _ciEquals(final String a, final String b) {
  if (identical(a, b)) return true;
  if (a.length != b.length) return false;
  for (var i = 0; i < a.length; i++) {
    if (_asciiFold(a.codeUnitAt(i)) != _asciiFold(b.codeUnitAt(i))) {
      return false;
    }
  }
  return true;
}

int _ciHash(final String s) {
  // FNV-1a 32-bit over ASCII-folded code units. Adequate for hashing short
  // header tokens; not a cryptographic primitive.
  var h = 0x811c9dc5;
  for (var i = 0; i < s.length; i++) {
    h ^= _asciiFold(s.codeUnitAt(i));
    h = (h * 0x01000193) & 0xFFFFFFFF;
  }
  return h;
}

int _asciiFold(final int c) {
  if (c >= 0x41 && c <= 0x5A) return c + 0x20; // uppercase ASCII -> lowercase
  return c;
}
