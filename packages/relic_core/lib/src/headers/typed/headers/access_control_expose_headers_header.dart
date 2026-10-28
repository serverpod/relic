import 'dart:typed_data';

import '../../../../relic_core.dart';
import '../primitives/byte_fields.dart';
import '../primitives/byte_scanner.dart' show latin1Bytes;
import 'wildcard_list_header.dart';

/// A class representing the HTTP Access-Control-Expose-Headers header.
///
/// This header specifies which headers can be exposed as part of the response
/// by listing them explicitly or using a wildcard (`*`) to expose all headers.
final class AccessControlExposeHeadersHeader
    extends WildcardListHeader<String> {
  static const codec = HeaderCodec.fields(_parseFields, _encode);

  /// Constructs an instance allowing specific headers to be exposed.
  ///
  /// Header names are case-insensitive (RFC 9110 5.1), so they are
  /// canonicalized to lowercase for case-insensitive equality and membership.
  AccessControlExposeHeadersHeader.headers(final Iterable<String> headers)
    : super(List.from(headers.map((final h) => h.toLowerCase())));

  /// Constructs an instance allowing all headers to be exposed (`*`).
  const AccessControlExposeHeadersHeader.wildcard() : super.wildcard();

  /// Parses the header [values].
  factory AccessControlExposeHeadersHeader.parse(
    final Iterable<String> values,
  ) => _parseFields([for (final value in values) latin1Bytes(value)]);

  AccessControlExposeHeadersHeader._owned(super.headers) : super.owned();

  /// The list of headers that can be exposed
  List<String> get headers => values;

  /// The header from the wire bytes of its [fields].
  static AccessControlExposeHeadersHeader _parseFields(
    final List<Uint8List> fields,
  ) {
    final parsed = WildcardListHeader.parseFields(fields, lowerTextOf);
    if (parsed.isWildcard) {
      return const AccessControlExposeHeadersHeader.wildcard();
    }
    return AccessControlExposeHeadersHeader._owned(parsed.values);
  }

  static List<String> encodeHeader(
    final AccessControlExposeHeadersHeader header,
  ) {
    return header.encode((final String str) => str).toList();
  }

  static List<String> _encode(final AccessControlExposeHeadersHeader header) {
    return encodeHeader(header);
  }
}
