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

    final splitValues = value.splitTrimAndFilterUnique(separator: ';');

    // RFC 6265 5.4 allows a Cookie header to carry several cookies with the
    // same name (e.g. a host-only cookie plus a Domain-scoped one, or
    // path-scoped duplicates); the server cannot tell them apart from the
    // header alone. Keep such same-name cookies rather than rejecting the
    // whole header, so one duplicate name does not make an otherwise valid
    // cookie unreadable. splitTrimAndFilterUnique still collapses byte-identical
    // segments, which is harmless since they are indistinguishable. [getCookie]
    // returns the first match. Cookie names are case-sensitive per RFC 6265
    // 4.2.2/5.4, so `Sid` and `sid` stay distinct.
    final cookies = splitValues.map(Cookie.parse).toList();

    return CookieHeader.cookies(cookies);
  }

  Cookie? getCookie(final String name) {
    return cookies.firstWhereOrNull((final cookie) => cookie.name == name);
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
