import 'package:meta/meta.dart';

/// An HTTP host reference per RFC 3986 section 3.2.2, used by `Host` headers,
/// the `Domain` attribute of cookies, and the `host=`/`for=` values in
/// `Forwarded`.
///
///     host        = IP-literal / IPv4address / reg-name
///     IP-literal  = "[" ( IPv6address / IPvFuture ) "]"
///
/// On the wire an IPv6 [host] is bracketed. In a [Host] instance the brackets
/// are not stored on the [host] field; the wire form is produced by [encode],
/// which adds brackets when [host] contains `:` (IPv6 / IPvFuture).
///
/// [port] is the optional explicit port (`uri-host [ ":" port ]`). An absent
/// port is represented by `null`; this is distinct from a default port (80,
/// 443, ...) which the [fromUri] factory takes care to preserve.
@immutable
final class Host {
  /// The host literal without IPv6 brackets. For example: `example.com`,
  /// `192.0.2.1`, `::1`. Case is preserved as supplied; equality is ASCII
  /// case-insensitive.
  final String host;

  /// The explicit port, or `null` when no port was supplied.
  final int? port;

  /// Creates a [Host] from its parts.
  ///
  /// Throws [FormatException] if [host] is empty or contains URI brackets
  /// (the brackets belong to the wire form only), or if [port] is outside
  /// the 0-65535 range.
  Host(this.host, [this.port]) {
    if (host.isEmpty) {
      throw const FormatException('host cannot be empty');
    }
    if (host.codeUnits.contains(0x5B) || host.codeUnits.contains(0x5D)) {
      throw FormatException(
        'host must not include URI brackets; pass the unbracketed value',
        host,
      );
    }
    // Reject control characters, whitespace, and structural delimiters. This
    // covers every host form (reg-name, IPv6, IPvFuture: none contain these)
    // and, critically, blocks CR/LF injection when a host built from
    // untrusted input is later serialized (e.g. into a cookie Domain).
    for (var i = 0; i < host.length; i++) {
      if (_isForbiddenHostChar(host.codeUnitAt(i))) {
        throw FormatException('invalid character in host', host, i);
      }
    }
    // A colon is only valid in an IP-literal (IPv6 / IPvFuture). Validating it
    // here rejects a reg-name like `a:b`, which would otherwise be bracketed
    // by [encode] to `[a:b]` and then fail to re-parse.
    if (host.codeUnits.contains(0x3A)) {
      _validateIpLiteral(host, host);
    }
    final p = port;
    if (p != null && (p < 0 || p > 65535)) {
      throw FormatException('port must be in 0-65535', p.toString());
    }
  }

  /// Creates a [Host] from a [Uri], honoring `Uri.hasPort` so that an
  /// implicit default port is left as `null` rather than coerced to 80/443.
  factory Host.fromUri(Uri uri) {
    if (uri.host.isEmpty) {
      throw FormatException('URI has no host', uri.toString());
    }
    return Host(uri.host, uri.hasPort ? uri.port : null);
  }

  /// Parses [source] as `uri-host [ ":" port ]`.
  ///
  /// IPv6 / IPvFuture hosts MUST be bracketed on the wire; unbracketed IPv6
  /// (e.g. `::1:80`) is ambiguous and rejected.
  factory Host.parse(String source) {
    if (source.isEmpty) {
      throw const FormatException('host cannot be empty');
    }
    if (source.startsWith('[')) {
      final close = source.indexOf(']');
      if (close < 0) {
        throw FormatException('unterminated IP-literal', source);
      }
      final inner = source.substring(1, close);
      if (inner.isEmpty) {
        throw FormatException('empty IP-literal', source);
      }
      _validateIpLiteral(inner, source);
      final tail = source.substring(close + 1);
      if (tail.isEmpty) return Host(inner);
      if (!tail.startsWith(':')) {
        throw FormatException(
          'expected ":port" or end after IP-literal',
          source,
          close + 1,
        );
      }
      return Host(inner, _parsePort(tail.substring(1), source));
    }
    final firstColon = source.indexOf(':');
    if (firstColon < 0) {
      return Host(source);
    }
    if (source.indexOf(':', firstColon + 1) >= 0) {
      throw FormatException(
        'unbracketed IPv6 host is ambiguous; use [ipv6]:port',
        source,
      );
    }
    final hostPart = source.substring(0, firstColon);
    return Host(hostPart, _parsePort(source.substring(firstColon + 1), source));
  }

  /// The wire form: `uri-host [ ":" port ]`, adding IPv6 brackets when [host]
  /// contains a colon.
  ///
  /// A colon-less IPvFuture host (`vX.…`, essentially never seen in practice)
  /// is not re-bracketed here, because it cannot be told apart from a
  /// versioned reg-name such as `v2.example.com` by content alone.
  String encode() {
    final h = host.codeUnits.contains(0x3A) ? '[$host]' : host;
    return port == null ? h : '$h:$port';
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is Host &&
          _asciiCaseInsensitiveEquals(host, other.host) &&
          port == other.port);

  @override
  int get hashCode => Object.hash(_asciiLower(host), port);

  @override
  String toString() => encode();

  /// Throws [FormatException] unless [authority] is `uri-host [":" port]`
  /// as [parse] accepts it.
  ///
  /// A name with an in-range port after one colon passes on a character
  /// scan alone. Whatever else the scan does not refuse goes through
  /// [parse], such as an IP literal, a second colon, a port that is not a
  /// number or is too large, or a colon with nothing on one side.
  static void checkAuthority(String authority) {
    if (authority.isEmpty) {
      throw const FormatException('Not a valid authority: empty');
    }
    var colonAt = -1;
    var port = 0;
    var parse = false;
    for (var i = 0; i < authority.length; i++) {
      final c = authority.codeUnitAt(i);
      if (c >= 0x80 || !_authorityChars[c]) {
        throw FormatException('Not a valid authority', authority);
      }
      if (c == 0x3a) {
        if (colonAt >= 0) parse = true;
        colonAt = i;
      } else if (c == 0x5b || c == 0x5d) {
        parse = true;
      } else if (colonAt >= 0) {
        if (c < 0x30 || c > 0x39) parse = true;
        port = port * 10 + (c - 0x30);
        if (port > 65535) parse = true;
      }
    }
    if (colonAt == 0 || colonAt == authority.length - 1) parse = true;
    if (parse) Host.parse(authority);
  }

  /// RFC 3986 unreserved and sub-delims, plus `:` for the port, `%` for an
  /// escape and the brackets of an IPv6 literal.
  static final _authorityChars = List<bool>.generate(128, (c) {
    const extra = r"-._~!$&'()*+,;=:%[]";
    return (c >= 0x30 && c <= 0x39) ||
        (c >= 0x41 && c <= 0x5a) ||
        (c >= 0x61 && c <= 0x7a) ||
        extra.codeUnits.contains(c);
  });
}

/// Validates the contents of an `IP-literal` (the text inside `[...]`).
///
/// Per RFC 3986 3.2.2 an IP-literal is `IPv6address` or `IPvFuture`. Without
/// this check `Host.parse('[zzz]')` would be accepted as a host named `zzz`.
void _validateIpLiteral(String inner, String source) {
  if (inner[0] == 'v' || inner[0] == 'V') {
    _validateIpvFuture(inner, source);
    return;
  }
  try {
    Uri.parseIPv6Address(inner);
  } on FormatException {
    throw FormatException('invalid IPv6 address in IP-literal', source);
  }
}

/// Validates `IPvFuture = "v" 1*HEXDIG "." 1*( unreserved / sub-delims / ":" )`.
void _validateIpvFuture(String inner, String source) {
  final dot = inner.indexOf('.');
  // Need at least one HEXDIG between the leading 'v' and the '.', and at least
  // one character after it.
  if (dot < 2 || dot == inner.length - 1) {
    throw FormatException('invalid IPvFuture literal', source);
  }
  for (var i = 1; i < dot; i++) {
    if (!_isHexDigit(inner.codeUnitAt(i))) {
      throw FormatException('invalid IPvFuture version', source);
    }
  }
  for (var i = dot + 1; i < inner.length; i++) {
    if (!_isIpvFutureTailChar(inner.codeUnitAt(i))) {
      throw FormatException('invalid IPvFuture character', source);
    }
  }
}

bool _isHexDigit(int c) =>
    (c >= 0x30 && c <= 0x39) ||
    (c >= 0x41 && c <= 0x46) ||
    (c >= 0x61 && c <= 0x66);

bool _isIpvFutureTailChar(int c) {
  // unreserved
  if ((c >= 0x41 && c <= 0x5A) || (c >= 0x61 && c <= 0x7A)) {
    return true; // ALPHA
  }
  if (c >= 0x30 && c <= 0x39) return true; // DIGIT
  if (c == 0x2D || c == 0x2E || c == 0x5F || c == 0x7E) return true; // - . _ ~
  // sub-delims: ! $ & ' ( ) * + , ; =
  switch (c) {
    case 0x21:
    case 0x24:
    case 0x26:
    case 0x27:
    case 0x28:
    case 0x29:
    case 0x2A:
    case 0x2B:
    case 0x2C:
    case 0x3B:
    case 0x3D:
    case 0x3A: // ":"
      return true;
  }
  return false;
}

bool _isForbiddenHostChar(int c) {
  if (c <= 0x20 || c == 0x7F) return true; // CTLs + SP + DEL
  switch (c) {
    case 0x22: // "
    case 0x23: // #
    case 0x2F: // /
    case 0x3C: // <
    case 0x3E: // >
    case 0x3F: // ?
    case 0x40: // @
    case 0x5C: // backslash
    case 0x5E: // ^
    case 0x60: // backtick
    case 0x7B: // {
    case 0x7C: // |
    case 0x7D: // }
      return true;
  }
  return false;
}

int _parsePort(String s, String source) {
  if (s.isEmpty) {
    throw FormatException('port cannot be empty', source);
  }
  if (s.length > 5) {
    throw FormatException('port out of range', source);
  }
  var v = 0;
  for (var i = 0; i < s.length; i++) {
    final c = s.codeUnitAt(i);
    if (c < 0x30 || c > 0x39) {
      throw FormatException('port must contain only digits', source);
    }
    v = v * 10 + (c - 0x30);
  }
  if (v > 65535) {
    throw FormatException('port must be in 0-65535', source);
  }
  return v;
}

bool _asciiCaseInsensitiveEquals(String a, String b) {
  if (identical(a, b)) return true;
  if (a.length != b.length) return false;
  for (var i = 0; i < a.length; i++) {
    if (_asciiFold(a.codeUnitAt(i)) != _asciiFold(b.codeUnitAt(i))) {
      return false;
    }
  }
  return true;
}

String _asciiLower(String s) {
  final buf = StringBuffer();
  for (var i = 0; i < s.length; i++) {
    buf.writeCharCode(_asciiFold(s.codeUnitAt(i)));
  }
  return buf.toString();
}

int _asciiFold(int c) {
  if (c >= 0x41 && c <= 0x5A) return c + 0x20;
  return c;
}
