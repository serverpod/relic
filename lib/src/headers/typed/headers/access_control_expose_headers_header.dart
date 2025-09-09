import '../../../../relic.dart';
import 'wildcard_list_header.dart';

/// A class representing the HTTP Access-Control-Expose-Headers header.
///
/// This header specifies which headers can be exposed as part of the response
/// by listing them explicitly or using a wildcard (`*`) to expose all headers.
final class AccessControlExposeHeadersHeader
    extends WildcardListHeader<String> {
  static const codec = HeaderCodec(_parse, _encode);

  /// Constructs an instance allowing specific headers to be exposed.
  AccessControlExposeHeadersHeader.headers(
      {required final Iterable<String> headers})
      : super(List.from(headers));

  /// Constructs an instance allowing all headers to be exposed (`*`).
  const AccessControlExposeHeadersHeader.wildcard() : super.wildcard();

  /// Parses the Access-Control-Expose-Headers header value and returns an
  /// [AccessControlExposeHeadersHeader] instance.
  factory AccessControlExposeHeadersHeader.parse(
      final Iterable<String> values) {
    return _parse(values);
  }

  /// The list of headers that can be exposed
  List<String> get headers => values;

  static AccessControlExposeHeadersHeader _parse(
      final Iterable<String> values) {
    final parsed =
        WildcardListHeader.parse(values, (final String value) => value);

    if (parsed.isWildcard) {
      return const AccessControlExposeHeadersHeader.wildcard();
    } else {
      return AccessControlExposeHeadersHeader.headers(headers: parsed.values);
    }
  }

  static List<String> encodeHeader(
      final AccessControlExposeHeadersHeader header) {
    return header.encode((final String str) => str).toList();
  }

  static List<String> _encode(final AccessControlExposeHeadersHeader header) {
    return encodeHeader(header);
  }
}
