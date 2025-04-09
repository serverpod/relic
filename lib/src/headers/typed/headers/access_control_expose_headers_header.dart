import '../../../../relic.dart';
import '../../extension/string_list_extensions.dart';

/// A class representing the HTTP Access-Control-Expose-Headers header.
///
/// This header specifies which headers can be exposed as part of the response
/// by listing them explicitly or using a wildcard (`*`) to expose all headers.
final class AccessControlExposeHeadersHeader {
  static const codec =
      HeaderCodec(AccessControlExposeHeadersHeader.parse, __encode);
  static List<String> __encode(final AccessControlExposeHeadersHeader value) =>
      [value._encode()];

  /// The list of headers that can be exposed.
  final Iterable<String>? headers;

  /// Whether all headers are allowed to be exposed (`*`).
  final bool isWildcard;

  /// Constructs an instance allowing specific headers to be exposed.
  const AccessControlExposeHeadersHeader.headers({required this.headers})
      : isWildcard = false;

  /// Constructs an instance allowing all headers to be exposed (`*`).
  const AccessControlExposeHeadersHeader.wildcard()
      : headers = null,
        isWildcard = true;

  /// Parses the Access-Control-Expose-Headers header value and returns an
  /// [AccessControlExposeHeadersHeader] instance.
  factory AccessControlExposeHeadersHeader.parse(
      final Iterable<String> values) {
    final splitValues = values.splitTrimAndFilterUnique();
    if (splitValues.isEmpty) {
      throw const FormatException('Value cannot be empty');
    }

    if (splitValues.length == 1 && splitValues.first == '*') {
      return const AccessControlExposeHeadersHeader.wildcard();
    }

    if (splitValues.length > 1 && splitValues.contains('*')) {
      throw const FormatException(
          'Wildcard (*) cannot be used with other values');
    }

    return AccessControlExposeHeadersHeader.headers(
      headers: splitValues,
    );
  }

  /// Converts the [AccessControlExposeHeadersHeader] instance into a string
  /// representation suitable for HTTP headers.

  String _encode() => isWildcard ? '*' : headers?.join(', ') ?? '';

  @override
  String toString() =>
      'AccessControlExposeHeadersHeader(headers: $headers, isWildcard: $isWildcard)';
}
