import '../../../../relic.dart';
import 'wildcard_list_header.dart';

/// A class representing the HTTP Access-Control-Allow-Headers header.
///
/// This header specifies which HTTP headers can be used during the actual request
/// by listing them explicitly or using a wildcard (`*`) to allow all headers.
final class AccessControlAllowHeadersHeader extends WildcardListHeader<String> {
  static const codec = HeaderCodec(_parse, _encode);

  /// Constructs an instance allowing specific headers to be allowed.
  AccessControlAllowHeadersHeader.headers(
      {required final Iterable<String> headers})
      : super(List.from(headers));

  /// Constructs an instance allowing all headers to be allowed (`*`).
  const AccessControlAllowHeadersHeader.wildcard() : super.wildcard();

  /// Parses the Access-Control-Allow-Headers header value and returns an
  /// [AccessControlAllowHeadersHeader] instance.
  factory AccessControlAllowHeadersHeader.parse(final Iterable<String> values) {
    return _parse(values);
  }

  /// The list of headers that are allowed
  List<String> get headers => values;

  static AccessControlAllowHeadersHeader _parse(final Iterable<String> values) {
    final parsed =
        WildcardListHeader.parse(values, (final String value) => value);

    if (parsed.isWildcard) {
      return const AccessControlAllowHeadersHeader.wildcard();
    } else {
      return AccessControlAllowHeadersHeader.headers(headers: parsed.values);
    }
  }

  static List<String> encodeHeader(
      final AccessControlAllowHeadersHeader header) {
    return header.encode((final String str) => str).toList();
  }

  static List<String> _encode(final AccessControlAllowHeadersHeader header) {
    return encodeHeader(header);
  }
}
