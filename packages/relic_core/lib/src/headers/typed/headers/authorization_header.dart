import 'dart:convert';

import '../../../../relic_core.dart';

/// An abstract base class representing an HTTP Authorization header.
///
/// This class serves as a blueprint for different types of authorization headers,
/// such as Bearer and Basic, by defining a method to return the header value.
/// The concrete subclasses handle specific header formats.
abstract class AuthorizationHeader {
  static const codec = HeaderCodec.single(AuthorizationHeader.parse, __encode);
  static List<String> __encode(final AuthorizationHeader value) => [
    value._encode(),
  ];

  /// Returns the value of the Authorization header as a string.
  String get headerValue;

  /// Converts the [AuthorizationHeader] instance into a string
  /// representation suitable for HTTP headers.

  String _encode() => headerValue;

  /// Parses and creates the appropriate [AuthorizationHeader]
  /// subclass based on the provided authorization string from HTTP headers.
  ///
  /// This method checks the header's prefix to determine whether it's a Bearer
  /// or Basic authorization type and returns the corresponding header object.
  ///
  /// Throws a [FormatException] if the header value is invalid or unrecognized.
  static AuthorizationHeader parse(final String value) {
    if (value.isEmpty) {
      throw const FormatException('Value cannot be empty');
    }

    // The auth-scheme is case-insensitive (RFC 9110 11.1).
    final sp = value.indexOf(' ');
    final scheme = (sp < 0 ? value : value.substring(0, sp)).toLowerCase();
    switch (scheme) {
      case 'bearer':
        return BearerAuthorizationHeader.parse(value);
      case 'basic':
        return BasicAuthorizationHeader.parse(value);
      case 'digest':
        return DigestAuthorizationHeader.parse(value);
      default:
        throw const FormatException('Invalid header format');
    }
  }
}

/// Strips a case-insensitive auth-scheme [prefix] (e.g. `"Bearer "`) from
/// [value], returning the trimmed remainder. Throws [FormatException] if
/// [value] does not start with [prefix].
String _stripScheme(final String value, final String prefix) {
  if (value.length < prefix.length ||
      value.substring(0, prefix.length).toLowerCase() != prefix.toLowerCase()) {
    throw FormatException('Invalid ${prefix.trim()} prefix', value);
  }
  return value.substring(prefix.length).trim();
}

/// Represents a Bearer token for HTTP Authorization.
///
/// Commonly used for stateless authentication in web APIs.
final class BearerAuthorizationHeader extends AuthorizationHeader {
  /// The default prefix used for Bearer token authentication.
  static const String prefix = 'Bearer ';

  /// The actual value of the authorization token.
  /// This should never be empty.
  final String token;

  /// Constructs a [BearerAuthorizationHeader] with the specified token.
  ///
  /// The token must not be empty.
  BearerAuthorizationHeader({required this.token}) {
    if (token.isEmpty) {
      throw const FormatException('Bearer token cannot be empty.');
    }
  }

  /// Factory constructor to create a [BearerAuthorizationHeader] from a token string.
  ///
  /// If the token starts with the "Bearer " prefix, the prefix is stripped
  /// from the token value. Otherwise, it throws a [FormatException].
  factory BearerAuthorizationHeader.parse(final String value) {
    if (value.isEmpty) {
      throw const FormatException('Bearer token cannot be empty.');
    }

    final token = _stripScheme(value, prefix);
    if (token.isEmpty) {
      throw const FormatException('Bearer token cannot be empty.');
    }

    return BearerAuthorizationHeader(token: token);
  }

  /// Returns the full authorization string, including the "Bearer " prefix.
  @override
  String get headerValue => '$prefix$token';

  @override
  bool operator ==(final Object other) =>
      identical(this, other) ||
      other is BearerAuthorizationHeader && token == other.token;

  @override
  int get hashCode => token.hashCode;

  @override
  String toString() => 'BearerAuthorizationHeader(token: ${_maskToken(token)})';

  /// Returns a string representation of this [BearerAuthorizationHeader] with
  /// the full token value exposed.
  ///
  /// **Warning**: This method should only be used for debugging purposes in
  /// secure environments. The token value is sensitive and should not be logged
  /// or exposed in production environments.
  String toStringInsecure() => 'BearerAuthorizationHeader(token: $token)';

  /// Masks a token value for secure logging.
  ///
  /// Shows the first 4 and last 4 characters of the token, with the middle
  /// replaced by asterisks. For tokens shorter than 16 characters, only
  /// asterisks are shown.
  static String _maskToken(final String token) {
    if (token.length < 16) {
      return '****';
    }
    final prefix = token.substring(0, 4);
    final suffix = token.substring(token.length - 4);
    return '$prefix****$suffix';
  }
}

/// Represents Basic authentication using a username and password.
///
/// The credentials are Base64-encoded and prefixed with "Basic ".
final class BasicAuthorizationHeader extends AuthorizationHeader {
  /// The default prefix used for Basic authentication.
  static const String prefix = 'Basic ';

  /// The username for Basic authentication.
  final String username;

  /// The password for Basic authentication.
  final String password;

  /// Constructs a [BasicAuthorizationHeader] with the specified [username] and [password].
  ///
  /// The credentials are encoded as "username:password" in Base64 and prefixed
  /// with "Basic ".
  BasicAuthorizationHeader({required this.username, required this.password}) {
    if (username.isEmpty) {
      throw const FormatException('Username cannot be empty');
    }
    if (username.contains(':')) {
      throw const FormatException('Username cannot contain ":"');
    }
    // RFC 7617 permits an empty password (e.g. the `apikey:` pattern), so it
    // is not rejected here.
  }

  /// Factory constructor to create a [BasicAuthorizationHeader] from a token string.
  ///
  /// The token should start with the "Basic " prefix, followed by Base64-encoded
  /// credentials. This method validates the Base64 format and splits the decoded
  /// string into username and password. If the token is invalid, it throws a [FormatException].
  factory BasicAuthorizationHeader.parse(final String value) {
    if (value.isEmpty) {
      throw const FormatException('Basic token cannot be empty.');
    }

    final base64Part = _stripScheme(value, prefix);

    try {
      final decoded = utf8.decode(base64Decode(base64Part));
      final split = decoded.indexOf(':');
      return BasicAuthorizationHeader(
        username: decoded.substring(0, split),
        password: decoded.substring(split + 1),
      );
    } catch (e) {
      throw const FormatException('Invalid basic token format');
    }
  }

  /// Returns the full authorization string, including the "Basic " prefix.
  @override
  String get headerValue {
    final credentials = base64Encode(utf8.encode('$username:$password'));
    return '$prefix$credentials';
  }

  @override
  bool operator ==(final Object other) =>
      identical(this, other) ||
      other is BasicAuthorizationHeader &&
          username == other.username &&
          password == other.password;

  @override
  int get hashCode => Object.hash(username, password);

  @override
  String toString() =>
      'BasicAuthorizationHeader(username: $username, password: ****)';

  /// Returns a string representation of this [BasicAuthorizationHeader] with
  /// the full password value exposed.
  ///
  /// **Warning**: This method should only be used for debugging purposes in
  /// secure environments. The password value is sensitive and should not be
  /// logged or exposed in production environments.
  String toStringInsecure() =>
      'BasicAuthorizationHeader(username: $username, password: $password)';
}

/// Represents Digest authentication for HTTP Authorization.
///
/// Digest authentication is a more secure method than Basic authentication
/// as it uses a challenge-response mechanism to verify credentials.
final class DigestAuthorizationHeader extends AuthorizationHeader {
  /// The default prefix used for Digest authentication.
  static const String prefix = 'Digest ';

  static const String _username = 'username';
  static const String _realm = 'realm';
  static const String _nonce = 'nonce';
  static const String _uri = 'uri';
  static const String _response = 'response';
  static const String _algorithm = 'algorithm';
  static const String _qop = 'qop';
  static const String _nc = 'nc';
  static const String _cnonce = 'cnonce';
  static const String _opaque = 'opaque';

  /// The username for Digest authentication.
  final String username;

  /// The realm in which the user is authenticated.
  final String realm;

  /// A server-specified data string which should be uniquely generated each time a 401 response is made.
  final String nonce;

  /// The URI of the requested resource.
  final String uri;

  /// The response hash calculated by the client.
  final String response;

  /// The algorithm used to hash the credentials.
  final String? algorithm;

  /// The quality of protection applied to the message.
  final String? qop;

  /// The nonce count, which is the hexadecimal count of the number of requests sent with the nonce value.
  final String? nc;

  /// The client nonce, which is an opaque string value provided by the client.
  final String? cnonce;

  /// An optional string of data specified by the server.
  final String? opaque;

  /// Constructs a [DigestAuthorizationHeader] with the specified parameters.
  DigestAuthorizationHeader({
    required this.username,
    required this.realm,
    required this.nonce,
    required this.uri,
    required this.response,
    this.algorithm,
    this.qop,
    this.nc,
    this.cnonce,
    this.opaque,
  }) {
    if (username.isEmpty) {
      throw const FormatException('Username cannot be empty');
    }
    if (realm.isEmpty) {
      throw const FormatException('Realm cannot be empty');
    }
    if (nonce.isEmpty) {
      throw const FormatException('Nonce cannot be empty');
    }
    if (uri.isEmpty) {
      throw const FormatException('URI cannot be empty');
    }
    if (response.isEmpty) {
      throw const FormatException('Response cannot be empty');
    }
    // algorithm/qop/nc are serialized as bare tokens (RFC 7616 3.4), so they
    // must be valid tokens to avoid emitting a malformed or injectable header.
    if (algorithm != null) Token.validate(algorithm!);
    if (qop != null) Token.validate(qop!);
    if (nc != null) Token.validate(nc!);
  }

  /// Parses a Digest authorization header value and returns a [DigestAuthorizationHeader] instance.
  ///
  /// This method extracts the various components of the Digest header from the provided string.
  /// Throws a [FormatException] if the header value is invalid or unrecognized.
  factory DigestAuthorizationHeader.parse(final String value) {
    if (value.isEmpty) {
      throw const FormatException('Digest token cannot be empty.');
    }

    // Each auth-param is `token = ( token / quoted-string )` (RFC 7616 3.4):
    // quoted-string values are DQUOTE-wrapped (group 2, with quoted-pair
    // escapes), token values are bare (group 3). Accepting both is required
    // because conformant peers send algorithm/qop/nc/stale unquoted.
    final Map<String, String> params = {};
    final regex = RegExp(r'(\w+)\s*=\s*(?:"((?:[^"\\]|\\.)*)"|([^",\s]+))');
    for (final match in regex.allMatches(value)) {
      final quoted = match.group(2);
      // A bare (unquoted) value must be a valid token; reject e.g.
      // `algorithm=MD5;evil`, which would otherwise be stored and re-emitted
      // verbatim.
      params[match.group(1)!] = quoted != null
          ? _unescapeQuoted(quoted)
          : Token.validate(match.group(3)!);
    }

    if (params.isEmpty) {
      throw const FormatException('Invalid digest token format');
    }

    final username = params[_username];
    if (username == null || username.isEmpty) {
      throw const FormatException('Username is required and cannot be empty');
    }

    final realm = params[_realm];
    if (realm == null || realm.isEmpty) {
      throw const FormatException('Realm is required and cannot be empty');
    }

    final nonce = params[_nonce];
    if (nonce == null || nonce.isEmpty) {
      throw const FormatException('Nonce is required and cannot be empty  ');
    }

    final uri = params[_uri];
    if (uri == null || uri.isEmpty) {
      throw const FormatException('URI is required and cannot be empty');
    }
    final response = params[_response];
    if (response == null || response.isEmpty) {
      throw const FormatException('Response is required and cannot be empty ');
    }

    return DigestAuthorizationHeader(
      username: username,
      realm: realm,
      nonce: nonce,
      uri: uri,
      response: response,
      algorithm: params[_algorithm],
      qop: params[_qop],
      nc: params[_nc],
      cnonce: params[_cnonce],
      opaque: params[_opaque],
    );
  }

  /// Returns the full authorization string for Digest authentication.
  ///
  /// Per RFC 7616 section 3.4, the `algorithm`, `qop`, `nc`, and `stale`
  /// parameters carry token values and MUST NOT be quoted on the wire; only
  /// `username`, `realm`, `nonce`, `uri`, `response`, `cnonce`, and `opaque`
  /// take quoted-string form. Strict server implementations (e.g. Apache
  /// `mod_auth_digest`) reject requests that quote the token-form parameters.
  @override
  String get headerValue {
    final params = [
      '$_username=${_quoteString(username)}',
      '$_realm=${_quoteString(realm)}',
      '$_nonce=${_quoteString(nonce)}',
      '$_uri=${_quoteString(uri)}',
      '$_response=${_quoteString(response)}',
      if (algorithm != null) '$_algorithm=$algorithm',
      if (qop != null) '$_qop=$qop',
      if (nc != null) '$_nc=$nc',
      if (cnonce != null) '$_cnonce=${_quoteString(cnonce!)}',
      if (opaque != null) '$_opaque=${_quoteString(opaque!)}',
    ];
    // RFC 7235 2.1: a single SP separates the auth-scheme from the first
    // auth-param; auth-params are then comma-separated.
    return 'Digest ${params.join(', ')}';
  }

  @override
  bool operator ==(final Object other) =>
      identical(this, other) ||
      other is DigestAuthorizationHeader &&
          username == other.username &&
          realm == other.realm &&
          nonce == other.nonce &&
          uri == other.uri &&
          response == other.response &&
          algorithm == other.algorithm &&
          qop == other.qop &&
          nc == other.nc &&
          cnonce == other.cnonce &&
          opaque == other.opaque;

  @override
  int get hashCode => Object.hashAll([
    username,
    realm,
    nonce,
    uri,
    response,
    algorithm,
    qop,
    nc,
    cnonce,
    opaque,
  ]);

  @override
  String toString() {
    return 'DigestAuthorizationHeader('
        '$_username: $username, '
        '$_realm: $realm, '
        '$_nonce: ****, '
        '$_uri: $uri, '
        '$_response: ****, '
        '$_algorithm: $algorithm, '
        '$_qop: $qop, '
        '$_nc: $nc, '
        '$_cnonce: ${cnonce != null ? '****' : null}, '
        '$_opaque: ${opaque != null ? '****' : null}'
        ')';
  }

  /// Returns a string representation of this [DigestAuthorizationHeader] with
  /// all field values exposed, including sensitive ones.
  ///
  /// **Warning**: This method should only be used for debugging purposes in
  /// secure environments. The nonce, response, cnonce, and opaque values are
  /// sensitive and should not be logged or exposed in production environments.
  String toStringInsecure() {
    return 'DigestAuthorizationHeader('
        '$_username: $username, '
        '$_realm: $realm, '
        '$_nonce: $nonce, '
        '$_uri: $uri, '
        '$_response: $response, '
        '$_algorithm: $algorithm, '
        '$_qop: $qop, '
        '$_nc: $nc, '
        '$_cnonce: $cnonce, '
        '$_opaque: $opaque'
        ')';
  }
}

/// Wraps [s] in DQUOTEs, escaping interior `"` and `\` as `quoted-pair`
/// (RFC 9110 5.6.4). Without this a value containing a quote would terminate
/// the quoted-string early and corrupt the parsed credentials.
String _quoteString(final String s) =>
    '"${s.replaceAll(r'\', r'\\').replaceAll('"', r'\"')}"';

/// Decodes `quoted-pair` escapes in a quoted-string body: `\x` becomes `x`.
String _unescapeQuoted(final String s) =>
    s.replaceAllMapped(RegExp(r'\\(.)'), (final m) => m.group(1)!);
