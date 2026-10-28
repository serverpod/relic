import 'dart:typed_data';

import '../../../../relic_core.dart';
import '../primitives/byte_fields.dart';
import '../primitives/byte_scanner.dart' show latin1Bytes;

/// A class representing the HTTP Sec-Fetch-Site header.
///
/// This header indicates the relationship between the origin of the request
/// initiator and the origin of the requested resource.
final class SecFetchSiteHeader {
  static const codec = HeaderCodec.bytes(_parseBytes, __encode);
  static List<String> __encode(final SecFetchSiteHeader value) => [
    value._encode(),
  ];

  /// The site value of the request.
  final String site;

  /// Private constructor for [SecFetchSiteHeader].
  const SecFetchSiteHeader._(this.site);

  /// Predefined site values.
  static const _sameOrigin = 'same-origin';
  static const _sameSite = 'same-site';
  static const _crossSite = 'cross-site';
  static const _none = 'none';

  static const sameOrigin = SecFetchSiteHeader._(_sameOrigin);
  static const sameSite = SecFetchSiteHeader._(_sameSite);
  static const crossSite = SecFetchSiteHeader._(_crossSite);
  static const none = SecFetchSiteHeader._(_none);

  /// Parses a [value] into a [SecFetchSiteHeader]. A value outside the
  /// predefined set is rejected; new Fetch values are adopted by updating the
  /// set in a relic release rather than accepted ad hoc.
  factory SecFetchSiteHeader.parse(final String value) =>
      _parseBytes(latin1Bytes(value));

  /// [parse] over the wire bytes.
  static SecFetchSiteHeader _parseBytes(final Uint8List bytes) {
    final value = trimmed(bytes);
    if (value.isEmpty) {
      throw const FormatException('Value cannot be empty');
    }
    switch (textOf(value)) {
      case _sameOrigin:
        return sameOrigin;
      case _sameSite:
        return sameSite;
      case _crossSite:
        return crossSite;
      case _none:
        return none;
      default:
        throw const FormatException('Invalid value');
    }
  }

  /// Converts the [SecFetchSiteHeader] instance into a string representation
  /// suitable for HTTP headers.

  String _encode() => site;

  @override
  bool operator ==(final Object other) =>
      identical(this, other) ||
      other is SecFetchSiteHeader && site == other.site;

  @override
  int get hashCode => site.hashCode;

  @override
  String toString() {
    return 'SecFetchSiteHeader(value: $site)';
  }
}
