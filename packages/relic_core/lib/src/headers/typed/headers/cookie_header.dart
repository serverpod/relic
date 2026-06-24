import 'package:collection/collection.dart';
import '../../../../relic_core.dart';
import '../../extension/string_list_extensions.dart';
import 'util/cookie_util.dart';

/// A class representing the HTTP Cookie header.
///
/// This class manages the parsing and representation of cookies.
final class CookieHeader {
  static const codec = HeaderCodec.single(CookieHeader.parse, __encode);
  static List<String> __encode(final CookieHeader value) => [value._encode()];

  /// The list of cookies.
  final List<Cookie> cookies;

  /// Constructs a [CookieHeader] instance with the specified cookies.
  CookieHeader.cookies(final List<Cookie> cookies)
    : assert(cookies.isNotEmpty),
      cookies = List.unmodifiable(cookies);

  /// Parses the Cookie header value and returns a [CookieHeader] instance.
  ///
  /// This method processes the header value, extracting the cookies into a list.
  factory CookieHeader.parse(final String value) {
    if (value.isEmpty) {
      throw const FormatException('Value cannot be empty');
    }

    final splitValues = value.splitAndTrim(separator: ';');

    // Parse each cookie independently and skip the malformed ones rather than
    // rejecting the entire header. The Cookie header is a single line carrying
    // every cookie the user agent decided to send; one invalid cookie (fx. a
    // stray third-party cookie that does not meet RFC 6265's grammar) must not
    // make the other, well-formed cookies - including a session or auth cookie
    // - unreadable.
    //
    // RFC 6265 5.4 also allows a Cookie header to carry several cookies with
    // the same name (a host-only cookie plus a Domain-scoped one, or
    // path-scoped duplicates).
    //
    // The server cannot tell them apart from the header alone, so keep every
    // segment - including byte-identical duplicates - rather than collapsing
    // them, so [getCookies] reports the true count. [getCookie] returns the
    // first match.
    //
    // Cookie names are case-sensitive per RFC 6265 4.2.2/5.4, so `Sid` and
    // `sid` stay distinct.
    final cookies = <Cookie>[];
    for (final cookie in splitValues) {
      try {
        final parsed = Cookie.parse(cookie);
        // A nameless segment like `=value` (or a bare `=`) is not a cookie the
        // client meaningfully set; skip it so such junk does not survive as an
        // empty-named entry and slip past the "no valid cookies" guard below.
        if (parsed.name.isEmpty) continue;
        cookies.add(parsed);
      } on FormatException {
        // Skip this malformed cookie; keep the rest.
      }
    }

    // The header is only treated as invalid when nothing in it is a usable
    // cookie (an empty value is already rejected above). Consumers that want a
    // tolerant read of a possibly-absent header can use `valueOrNullIfInvalid`.
    if (cookies.isEmpty) {
      throw const FormatException('No valid cookies in Cookie header');
    }

    return CookieHeader.cookies(cookies);
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
