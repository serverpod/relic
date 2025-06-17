import 'package:collection/collection.dart';
import '../../../../relic.dart';
import '../../extension/string_list_extensions.dart';

/// Typed representation of the `X-Forwarded-For` (XFF) HTTP header.
///
/// This header is a de-facto standard for identifying the originating IP address
/// of a client connecting to a web server through an HTTP proxy or a load balancer.
/// It typically contains a comma-separated list of IP addresses, with the leftmost
/// being the original client and each subsequent proxy adding the IP address of the
/// incoming request.
///
/// See [MDN Web Docs: X-Forwarded-For](https://developer.mozilla.org/en-US/docs/Web/HTTP/Headers/X-Forwarded-For)
/// and [RFC 7239, Section 5.2](https://tools.ietf.org/html/rfc7239#section-5.2).
final class XForwardedForHeader {
  /// The list of IP addresses or "unknown" placeholders.
  /// The order is significant: the first IP is the original client,
  /// subsequent IPs are proxies.
  final List<String> addresses;

  /// Creates an [XForwardedForHeader] with the given list of addresses.
  XForwardedForHeader(final Iterable<String> addresses)
      : addresses = List.unmodifiable(addresses);

  /// Parses the `X-Forwarded-For` header values into an [XForwardedForHeader].
  factory XForwardedForHeader.parse(final Iterable<String> values) {
    final parsedAddresses = values.splitAndTrim(); // 'unknown' may repeat
    if (parsedAddresses.isEmpty) {
      throw const FormatException('Value cannot be empty');
    }
    return XForwardedForHeader(parsedAddresses);
  }

  /// The [HeaderCodec] for [XForwardedForHeader].
  static const codec = HeaderCodec<XForwardedForHeader>(
    XForwardedForHeader.parse,
    __encode,
  );

  static List<String> __encode(final XForwardedForHeader value) =>
      [value._encode()];
  String _encode() => addresses.join(', ');

  @override
  bool operator ==(final Object other) =>
      identical(this, other) ||
      other is XForwardedForHeader &&
          const ListEquality<String>().equals(addresses, other.addresses);

  @override
  int get hashCode => const ListEquality<String>().hash(addresses);

  @override
  String toString() => 'XForwardedForHeader(addresses: $addresses)';
}
