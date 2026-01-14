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

    final cookies = splitValues.map(Cookie.parse).toList();
    final names = cookies
        .map((final cookie) => cookie.name.toLowerCase())
        .toList();
    final uniqueNames = names.toSet();

    if (names.length != uniqueNames.length) {
      throw const FormatException(
        'Supplied multiple Name and Value attributes',
      );
    }

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
    final splitValue = value.split('=');
    if (splitValue.length != 2) {
      throw const FormatException('Invalid cookie format');
    }

    return Cookie(name: splitValue.first.trim(), value: splitValue.last.trim());
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
