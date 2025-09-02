import '../../../../relic.dart';

/// Wanna-be RFC3986 compliant 'Host' header.
final class HostHeader {
  static const codec = HeaderCodec.single(HostHeader.parse, __encode);
  static List<String> __encode(final HostHeader value) => [value._encode()];

  final String host;
  // TODO: This should default 80 for http, or 443 for https, but we don't have
  // access to the scheme in HostHeader.parse. Will require some refactoring,
  // perhaps allowing Header instances to know what Request instance they belong
  // to. For now allow port to be null, at leave it to the client to handle.
  final int? port;
  HostHeader._(this.host, this.port);

  factory HostHeader(final String host, [final int? port]) {
    return HostHeader._(host.trim().toLowerCase(), port);
  }

  factory HostHeader.parse(final String value) {
    String hostFrom(final String value) {
      final trimmed = value.trim();
      if (trimmed.isEmpty) {
        throw const FormatException('Value cannot be empty');
      }
      return trimmed;
    }

    final lastColon = value.lastIndexOf(':');
    if (lastColon < 0) {
      // no port, and not IPv6
      return HostHeader(hostFrom(value), null);
    }
    final ipV6End = value.lastIndexOf(']');
    if (ipV6End > lastColon) {
      // IPv6 no port
      return HostHeader(hostFrom(value), null);
    }
    final port = int.parse(value.substring(lastColon + 1));
    return HostHeader(hostFrom(value.substring(0, lastColon)), port);
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
}
