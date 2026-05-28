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
    final p = port;
    if (p != null && (p < 0 || p > 65535)) {
      throw FormatException('port must be in 0-65535', p.toString());
    }
  }

  /// Creates a [Host] from a [Uri], honoring `Uri.hasPort` so that an
  /// implicit default port is left as `null` rather than coerced to 80/443.
  factory Host.fromUri(final Uri uri) {
    if (uri.host.isEmpty) {
      throw FormatException('URI has no host', uri.toString());
    }
    return Host(uri.host, uri.hasPort ? uri.port : null);
  }

  /// Parses [source] as `uri-host [ ":" port ]`.
  ///
  /// IPv6 / IPvFuture hosts MUST be bracketed on the wire; unbracketed IPv6
  /// (e.g. `::1:80`) is ambiguous and rejected.
  factory Host.parse(final String source) {
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
  String encode() {
    final h = host.codeUnits.contains(0x3A) ? '[$host]' : host;
    return port == null ? h : '$h:$port';
  }

  @override
  bool operator ==(final Object other) =>
      identical(this, other) ||
      (other is Host &&
          _asciiCaseInsensitiveEquals(host, other.host) &&
          port == other.port);

  @override
  int get hashCode => Object.hash(_asciiLower(host), port);

  @override
  String toString() => encode();
}

/// Validates the contents of an `IP-literal` (the text inside `[...]`).
///
/// Per RFC 3986 3.2.2 an IP-literal is `IPv6address` or `IPvFuture`. Without
/// this check `Host.parse('[zzz]')` would be accepted as a host named `zzz`.
void _validateIpLiteral(final String inner, final String source) {
  // IPvFuture = "v" 1*HEXDIG "." 1*( unreserved / sub-delims / ":" )
  if (inner.length >= 2 && (inner[0] == 'v' || inner[0] == 'V')) {
    if (inner.contains('.')) return;
    throw FormatException('invalid IPvFuture literal', source);
  }
  try {
    Uri.parseIPv6Address(inner);
  } on FormatException {
    throw FormatException('invalid IPv6 address in IP-literal', source);
  }
}

int _parsePort(final String s, final String source) {
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

bool _asciiCaseInsensitiveEquals(final String a, final String b) {
  if (identical(a, b)) return true;
  if (a.length != b.length) return false;
  for (var i = 0; i < a.length; i++) {
    if (_asciiFold(a.codeUnitAt(i)) != _asciiFold(b.codeUnitAt(i))) {
      return false;
    }
  }
  return true;
}

String _asciiLower(final String s) {
  final buf = StringBuffer();
  for (var i = 0; i < s.length; i++) {
    buf.writeCharCode(_asciiFold(s.codeUnitAt(i)));
  }
  return buf.toString();
}

int _asciiFold(final int c) {
  if (c >= 0x41 && c <= 0x5A) return c + 0x20;
  return c;
}
