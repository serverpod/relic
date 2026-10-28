import 'dart:typed_data';

import '../../../../relic_core.dart';
import '../primitives/byte_fields.dart';
import '../primitives/byte_scanner.dart' show latin1Bytes;
import 'wildcard_list_header.dart';

/// A class representing the HTTP Access-Control-Allow-Headers header.
///
/// This header specifies which HTTP headers can be used during the actual request
/// by listing them explicitly or using a wildcard (`*`) to allow all headers.
final class AccessControlAllowHeadersHeader extends WildcardListHeader<String> {
  static const codec = HeaderCodec.fields(_parseFields, _encode);

  /// Constructs an instance allowing specific headers to be allowed.
  ///
  /// Header names are case-insensitive (RFC 9110 5.1), so they are
  /// canonicalized to lowercase for case-insensitive equality and membership.
  AccessControlAllowHeadersHeader.headers(final Iterable<String> headers)
    : super(List.from(headers.map((final h) => h.toLowerCase())));

  /// Constructs an instance allowing all headers to be allowed (`*`).
  const AccessControlAllowHeadersHeader.wildcard() : super.wildcard();

  /// Parses the header [values].
  factory AccessControlAllowHeadersHeader.parse(
    final Iterable<String> values,
  ) => _parseFields([for (final value in values) latin1Bytes(value)]);

  AccessControlAllowHeadersHeader._owned(super.headers) : super.owned();

  /// The list of headers that are allowed
  List<String> get headers => values;

  /// The header from the wire bytes of its [fields].
  static AccessControlAllowHeadersHeader _parseFields(
    final List<Uint8List> fields,
  ) {
    final parsed = WildcardListHeader.parseFields(fields, lowerTextOf);
    if (parsed.isWildcard) {
      return const AccessControlAllowHeadersHeader.wildcard();
    }
    return AccessControlAllowHeadersHeader._owned(parsed.values);
  }

  static List<String> encodeHeader(
    final AccessControlAllowHeadersHeader header,
  ) {
    return header.encode((final String str) => str).toList();
  }

  static List<String> _encode(final AccessControlAllowHeadersHeader header) {
    return encodeHeader(header);
  }
}
