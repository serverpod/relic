import 'package:http_parser/http_parser.dart';
import '../../../../relic_core.dart';

import '../../extension/string_list_extensions.dart';
import 'util/cookie_util.dart';

/// A class representing the HTTP Set-Cookie header.
///
/// This class manages the parsing and representation of set cookie.
final class SetCookieHeader {
  static const codec = HeaderCodec.single(SetCookieHeader.parse, __encode);
  static List<String> __encode(final SetCookieHeader value) => [
    value._encode(),
  ];

  /// The keys used for the Set-Cookie header.
  static const String _expires = 'Expires=';
  static const String _maxAge = 'Max-Age=';
  static const String _domain = 'Domain=';
  static const String _path = 'Path=';
  static const String _secure = 'Secure';
  static const String _httpOnly = 'HttpOnly';
  static const String _sameSite = 'SameSite=';

  /// The name of the cookie.
  final String name;

  /// The value of the cookie.
  final String value;

  /// The time at which the cookie expires.
  final DateTime? expires;

  /// The number of seconds until the cookie expires. A zero or negative value
  /// means the cookie has expired.
  final int? maxAge;

  /// The domain that the cookie applies to.
  ///
  /// Per RFC 6265 5.2.3, this is a bare hostname (`<subdomain>`): no scheme,
  /// no leading slashes, no port, no path. Modeling it as [Host] enforces
  /// that on construction and on the wire.
  final Host? domain;

  /// The path within the [domain] that the cookie applies to.
  ///
  /// Per RFC 6265 5.2.4, this is an opaque string (any CHAR except CTLs or
  /// `;`); it is not a URI.
  final String? path;

  /// Whether to only send this cookie on secure connections.
  final bool secure;

  /// Whether the cookie is only sent in the HTTP request and is not made
  /// available to client side scripts.
  final bool httpOnly;

  /// Whether the cookie is available from other sites.
  ///
  /// This value is `null` if the SameSite attribute is not present.
  ///
  /// See [SameSite] for more information.
  final SameSite? sameSite;

  /// Constructs a [Cookie] instance with the specified name and value.
  ///
  /// Per RFC 6265 5.2.3 the `Domain` attribute is host-only, so [domain] must
  /// not carry a port; a [Host] with a port throws [FormatException]. [path]
  /// is validated against the path-value grammar (no CTLs or `;`).
  SetCookieHeader({
    required final String name,
    required final String value,
    this.expires,
    this.maxAge,
    final Host? domain,
    final String? path,
    this.secure = false,
    this.httpOnly = false,
    this.sameSite,
  }) : name = validateCookieName(name),
       value = validateCookieValue(value),
       domain = _validateCookieDomain(domain),
       path = path == null ? null : validateCookiePath(path);

  static Host? _validateCookieDomain(final Host? domain) {
    if (domain != null && domain.port != null) {
      throw const FormatException(
        'Cookie Domain must not include a port (RFC 6265 5.2.3)',
      );
    }
    return domain;
  }

  factory SetCookieHeader.parse(final String value) {
    final splitValue = value.splitTrimAndFilterUnique(separator: ';');
    if (splitValue.isEmpty) {
      throw const FormatException('Value cannot be empty');
    }

    // RFC 6265 5.2: the first ';'-delimited token is the cookie-pair; every
    // subsequent token is a cookie attribute (cookie-av). Splitting on the
    // first '=' keeps a '=' that appears inside the value or an attribute.
    final pair = splitValue.first;
    final pairEq = pair.indexOf('=');
    if (pairEq < 0) {
      throw const FormatException('Invalid cookie format');
    }
    final cookieName = pair.substring(0, pairEq).trim();
    final cookieValue = pair.substring(pairEq + 1).trim();

    bool secure = false;
    bool httpOnly = false;
    SameSite? sameSite;
    DateTime? expires;
    int? maxAge;
    Host? domain;
    String? path;

    for (final av in splitValue.skip(1)) {
      final eq = av.indexOf('=');
      final attrName = (eq < 0 ? av : av.substring(0, eq)).trim();
      final attrValue = eq < 0 ? '' : av.substring(eq + 1).trim();

      switch (attrName.toLowerCase()) {
        case 'samesite':
          if (sameSite != null) {
            throw const FormatException(
              'Supplied multiple SameSite attributes',
            );
          }
          sameSite = SameSite.values.firstWhere(
            (final s) => s.name.toLowerCase() == attrValue.toLowerCase(),
            orElse: () =>
                throw const FormatException('Invalid SameSite attribute'),
          );
        case 'path':
          if (path != null) {
            throw const FormatException('Supplied multiple Path attributes');
          }
          path = attrValue;
        case 'domain':
          if (domain != null) {
            throw const FormatException('Supplied multiple Domain attributes');
          }
          domain = Host.parse(attrValue);
        case 'max-age':
          if (maxAge != null) {
            throw const FormatException('Supplied multiple Max-Age attributes');
          }
          maxAge = parseInt(attrValue);
        case 'expires':
          if (expires != null) {
            throw const FormatException('Supplied multiple Expires attributes');
          }
          expires = parseDate(attrValue);
        case 'secure':
          secure = true;
        case 'httponly':
          httpOnly = true;
        default:
        // RFC 6265 5.2: ignore unrecognized attributes (e.g. future tokens
        // like `Partitioned`, `Priority`) rather than failing the parse.
      }
    }

    return SetCookieHeader(
      name: cookieName,
      value: cookieValue,
      secure: secure,
      httpOnly: httpOnly,
      sameSite: sameSite,
      path: path,
      domain: domain,
      maxAge: maxAge,
      expires: expires,
    );
  }

  /// Converts the [Cookie] instance into a string representation suitable for HTTP headers.

  String _encode() {
    // Each attribute is emitted at most once by construction, so a plain list
    // is correct here; a Set would silently collapse a cookie-pair whose name
    // coincides with an attribute rendering (e.g. name 'Path', value '/x').
    final attributes = <String>[];
    if (name.isNotEmpty) attributes.add('$name=$value');

    if (secure) attributes.add(_secure);
    if (httpOnly) attributes.add(_httpOnly);
    if (sameSite != null) attributes.add('$_sameSite${sameSite!.name}');
    if (expires != null) {
      attributes.add('$_expires${formatHttpDate(expires!)}');
    }
    if (maxAge != null) attributes.add('$_maxAge$maxAge');
    if (domain != null) attributes.add('$_domain${domain!.encode()}');
    if (path != null) attributes.add('$_path$path');

    return attributes.join('; ');
  }

  @override
  bool operator ==(final Object other) =>
      identical(this, other) ||
      other is SetCookieHeader &&
          name == other.name &&
          value == other.value &&
          expires == other.expires &&
          maxAge == other.maxAge &&
          domain == other.domain &&
          path == other.path &&
          secure == other.secure &&
          httpOnly == other.httpOnly &&
          sameSite == other.sameSite;

  @override
  int get hashCode => Object.hashAll([
    name,
    value,
    expires,
    maxAge,
    domain,
    path,
    secure,
    httpOnly,
    sameSite,
  ]);

  @override
  String toString() {
    return 'SetCookieHeader(name: $name, '
        'value: $value, '
        'expires: $expires, '
        'maxAge: $maxAge, '
        'domain: $domain, '
        'path: $path, '
        'secure: $secure, '
        'httpOnly: $httpOnly, '
        'sameSite: $sameSite)';
  }
}

/// Cookie cross-site availability configuration.
///
/// The value of [Cookie.sameSite], which defines whether an
/// HTTP cookie is available from other sites or not.
///
/// Has three possible values: [lax], [strict] and [none].
final class SameSite {
  /// Default value, cookie with this value will generally not be sent on
  /// cross-site requests, unless the user is navigated to the original site.
  static const lax = SameSite._('Lax');

  /// Cookie with this value will never be sent on cross-site requests.
  static const strict = SameSite._('Strict');

  /// Cookie with this value will be sent in all requests.
  ///
  /// [Cookie.secure] must also be set to true, otherwise the `none` value
  /// will have no effect.
  static const none = SameSite._('None');

  static const List<SameSite> values = [lax, strict, none];

  final String name;

  const SameSite._(this.name);

  @override
  String toString() => 'SameSite($name)';
}
