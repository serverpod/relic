import 'dart:typed_data';

import 'package:collection/collection.dart';
import '../../../../relic_core.dart';
import '../primitives/byte_scanner.dart' show latin1Bytes;
import 'util/cookie_util.dart';

/// A class representing the HTTP Cookie header.
///
/// This class manages the parsing and representation of cookies.
final class CookieHeader {
  static const codec = HeaderCodec.bytes(_parseBytes, __encode);
  static List<String> __encode(final CookieHeader value) => [value._encode()];

  /// The list of cookies.
  final List<Cookie> cookies;

  /// Constructs a [CookieHeader] instance with the specified cookies.
  CookieHeader.cookies(final List<Cookie> cookies)
    : assert(cookies.isNotEmpty),
      cookies = List.unmodifiable(cookies);

  /// Takes [cookies], a list the parser built, as its own.
  const CookieHeader._(this.cookies);

  /// Parses the Cookie header value and returns a [CookieHeader] instance.
  ///
  /// This method processes the header value, extracting the cookies into a list.
  factory CookieHeader.parse(final String value) =>
      _parseBytes(latin1Bytes(value));

  /// The header from the wire [bytes] of its value.
  ///
  /// The parser reads each segment on its own and skips a malformed one
  /// rather than failing the header. The Cookie header is a single line
  /// carrying every cookie the user agent decided to send. One invalid
  /// cookie, say a stray third-party cookie outside RFC 6265's grammar,
  /// must not make the well-formed ones unreadable, a session or auth
  /// cookie among them.
  ///
  /// RFC 6265 5.4 also allows a Cookie header to carry several cookies with
  /// the same name (a host-only cookie plus a Domain-scoped one, or
  /// path-scoped duplicates). The server cannot tell them apart from the
  /// header alone, so every segment is kept, byte-identical duplicates
  /// included, so [getCookies] reports the true count. [getCookie] returns
  /// the first match. Cookie names are case-sensitive per RFC 6265
  /// 4.2.2/5.4, so `Sid` and `sid` stay distinct.
  static CookieHeader _parseBytes(final Uint8List bytes) {
    if (bytes.isEmpty) {
      throw const FormatException('Value cannot be empty');
    }
    final cookies = <Cookie>[];
    final classes = cookieByteClasses;
    final length = bytes.length;
    var i = 0;
    // One pass per segment: the name up to `=`, then the value up to `;`,
    // each byte classified once. The segment is a cookie when the name is
    // one run of name characters and the value one run of cookie-octets,
    // inside one pair of double quotes or not, whitespace around both
    // trimmed as `String.trim` trims it.
    while (i <= length) {
      while (i < length && classes[bytes[i]] & cookieWhitespace != 0) {
        i++;
      }
      final nameStart = i;
      var nameEnd = i;
      var ok = true;
      var b = 0;
      while (i < length) {
        b = bytes[i];
        if (b == 0x3D || b == 0x3B) break;
        final c = classes[b];
        if (c & cookieNameChar != 0) {
          if (nameEnd != i && nameEnd != nameStart) ok = false;
          nameEnd = i + 1;
        } else if (c & cookieWhitespace == 0) {
          ok = false;
        }
        i++;
      }
      if (i == length || b == 0x3B) {
        // No `=`: not a cookie.
        i++;
        continue;
      }
      i++;
      while (i < length && classes[bytes[i]] & cookieWhitespace != 0) {
        i++;
      }
      final valueStart = i;
      var valueEnd = i;
      var quotes = 0;
      var lastQuote = -1;
      while (i < length) {
        b = bytes[i];
        if (b == 0x3B) break;
        final c = classes[b];
        if (c & cookieWhitespace != 0) {
          i++;
          continue;
        }
        if (valueEnd != i && valueEnd != valueStart) ok = false;
        if (b == 0x22) {
          if (quotes == 0 && i != valueStart) ok = false;
          quotes++;
          lastQuote = i;
        } else if (c & cookieOctet == 0) {
          ok = false;
        }
        valueEnd = i + 1;
        i++;
      }
      i++;
      if (quotes != 0 && (quotes != 2 || lastQuote != valueEnd - 1)) {
        ok = false;
      }
      if (ok && nameEnd > nameStart) {
        cookies.add(
          Cookie._(
            String.fromCharCodes(bytes, nameStart, nameEnd),
            String.fromCharCodes(bytes, valueStart, valueEnd),
          ),
        );
      }
    }
    if (cookies.isEmpty) {
      throw const FormatException('No valid cookies in Cookie header');
    }
    return CookieHeader._(cookies);
  }

  /// Returns the first cookie named [name], or `null` if absent.
  ///
  /// A `Cookie` header may carry more than one cookie with the same name (RFC 6265 5.4).
  /// Use [getCookies] when you must distinguish "exactly one" from a duplicate,
  /// rather than blindly trusting the first.
  Cookie? getCookie(final String name) {
    return cookies.firstWhereOrNull((final cookie) => cookie.name == name);
  }

  /// Returns every cookie named [name], in header order (possibly empty).
  Iterable<Cookie> getCookies(final String name) {
    return cookies.where((final cookie) => cookie.name == name);
  }

  /// Converts the [CookieHeader] instance into a string representation
  /// suitable for HTTP headers.

  String _encode() {
    return cookies.map((final cookie) => cookie._encode()).join('; ');
  }

  @override
  bool operator ==(final Object other) =>
      identical(this, other) ||
      other is CookieHeader &&
          const ListEquality<Cookie>().equals(cookies, other.cookies);

  @override
  int get hashCode => const ListEquality<Cookie>().hash(cookies);

  @override
  String toString() {
    return 'CookieHeader(cookies: $cookies)';
  }
}

/// A class representing a single cookie.
class Cookie {
  /// The name of the cookie.
  final String name;

  /// The value of the cookie.
  final String value;

  Cookie({required final String name, required final String value})
    : name = validateCookieName(name),
      value = validateCookieValue(value);

  const Cookie._(this.name, this.value);

  factory Cookie.parse(final String value) {
    // Split on the FIRST '=' only; RFC 6265 cookie-octets permit '=' to
    // appear inside the value (e.g. base64 padding).
    final eq = value.indexOf('=');
    if (eq < 0) {
      throw const FormatException('Invalid cookie format');
    }
    return Cookie(
      name: value.substring(0, eq).trim(),
      value: value.substring(eq + 1).trim(),
    );
  }

  /// Converts the [Cookie] instance into a string representation suitable for HTTP headers.
  String _encode() => '$name=$value';

  @override
  bool operator ==(final Object other) =>
      identical(this, other) ||
      other is Cookie && name == other.name && value == other.value;

  @override
  int get hashCode => Object.hash(name, value);

  @override
  String toString() {
    return 'Cookie(name: $name, value: $value)';
  }
}
