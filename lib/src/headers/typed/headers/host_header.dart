import '../../../../relic.dart';

/// Wanna-be RFC3986 compliant 'Host' header.
final class HostHeader {
  static const codec = HeaderCodec.single(HostHeader.parse, __encode);
  static List<String> __encode(final HostHeader value) => [value._encode()];

  final String host;
  final int? port;
  HostHeader._(this.host, this.port);

  factory HostHeader(final String host, [final int? port]) {
    return HostHeader._(host.trim().toLowerCase(), port);
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
      final port = int.parse(value.substring(lastColon + 1));
      return HostHeader(host, port);
    }
  }

  HostHeader.fromUri(final Uri uri) : this._(uri.host, uri.port);

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
