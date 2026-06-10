import '../../../../relic_core.dart';

/// Wanna-be RFC3986 compliant 'Host' header.
final class HostHeader {
  static const codec = HeaderCodec.single(HostHeader.parse, __encode);
  static List<String> __encode(final HostHeader value) => [value._encode()];

  final String host;
  final int? port;
  HostHeader._(this.host, this.port);

  factory HostHeader(final String host, [final int? port]) {
    final trimmed = host.trim();
    if (trimmed.isEmpty) {
      throw const FormatException('Host cannot be empty');
    }
    if (port != null && (port < 0 || port > 65535)) {
      throw FormatException('Port out of range', port.toString());
    }
    return HostHeader._(trimmed.toLowerCase(), port);
  }

  factory HostHeader.parse(String value) {
    value = value.trim();
    if (value.isEmpty) {
      throw const FormatException('Value cannot be empty');
    }

    // Delegate to Uri to handle the grunt of parsing
    // Add schema as prefix as it is not (/should not be)
    // included in Host header itself.
    final uri = Uri.tryParse('http://$value');
    if (uri == null ||
        !uri.hasEmptyPath ||
        uri.hasQuery ||
        uri.hasFragment ||
        uri.userInfo.isNotEmpty) {
      // Only host and port allowed!
      throw FormatException('Invalid host', value);
    }

    final String host;

    // IPv6, or not?
    final lastBracket = value.lastIndexOf(']');
    if (lastBracket >= 0) {
      Uri.parseIPv6Address(uri.host); // throws if invalid
      host = '[${uri.host}]'; // preserve brackets
    } else {
      host = uri.host;
    }

    // We need to parse port explicitly, as Uri adds implicit port
    final lastColon = value.lastIndexOf(':');
    if (lastColon <= lastBracket) {
      // no port
      return HostHeader(host, null);
    } else {
      return HostHeader(
        host,
        _parsePort(value.substring(lastColon + 1), value),
      );
    }
  }

  /// Parses a port as digits only (RFC 9110 7.2 `port = *DIGIT`), throwing
  /// [FormatException] for a non-digit, empty, or out-of-range value. Unlike
  /// `int.parse`, this rejects `0x..`, a leading sign, and surrounding
  /// whitespace, and reports a consistent 'Port out of range' message.
  static int _parsePort(final String s, final String source) {
    if (s.isEmpty) {
      throw FormatException('Port cannot be empty', source);
    }
    if (s.length > 5) {
      throw FormatException('Port out of range', source);
    }
    var v = 0;
    for (var i = 0; i < s.length; i++) {
      final c = s.codeUnitAt(i);
      if (c < 0x30 || c > 0x39) {
        throw FormatException('Port must contain only digits', source);
      }
      v = v * 10 + (c - 0x30);
    }
    if (v > 65535) {
      throw FormatException('Port out of range', source);
    }
    return v;
  }

  /// Constructs a [HostHeader] from a [Uri].
  ///
  /// Preserves the absence of an explicit port: a URI like
  /// `http://example.com/` produces `port: null` rather than the default
  /// `80`, matching RFC 9110 7.2 (`Host = uri-host [ ":" port ]`).
  ///
  /// Dart's [Uri.host] returns an IPv6 address without its brackets, but the
  /// `Host` wire form requires them (RFC 3986 `host = IP-literal`). They are
  /// re-added here so [HostHeader.fromUri] matches [HostHeader.parse] (which
  /// keeps the brackets) and encodes unambiguous syntax. Routing through the
  /// public factory also applies the same normalization and port-range check
  /// as the other constructors.
  factory HostHeader.fromUri(final Uri uri) {
    final host = uri.host.contains(':') ? '[${uri.host}]' : uri.host;
    return HostHeader(host, uri.hasPort ? uri.port : null);
  }

  String _encode() => port == null ? host : '$host:$port';

  @override
  bool operator ==(final Object other) {
    if (identical(this, other)) return true;
    if (other is! HostHeader) return false;
    return host == other.host && port == other.port;
  }

  @override
  int get hashCode => Object.hash(host, port);

  @override
  String toString() => 'Host(host: $host, port: $port)';
}
