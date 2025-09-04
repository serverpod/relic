import 'package:collection/collection.dart';

import '../../../../relic.dart';
import '../../extension/string_list_extensions.dart';

/// A class representing the HTTP Access-Control-Allow-Headers header.
///
/// This header specifies which HTTP headers can be used during the actual request
/// by listing them explicitly or using a wildcard (`*`) to allow all headers.
final class AccessControlAllowHeadersHeader {
  static const codec =
      HeaderCodec(AccessControlAllowHeadersHeader.parse, __encode);
  static List<String> __encode(final AccessControlAllowHeadersHeader value) =>
      [value._encode()];

  /// The list of headers that are allowed.
  final Iterable<String> headers;

  /// Whether all headers are allowed (`*`).
  final bool isWildcard;

  /// Constructs an instance allowing specific headers to be allowed.
  AccessControlAllowHeadersHeader.headers({required this.headers})
      : assert(headers.isNotEmpty),
        isWildcard = false;

  /// Constructs an instance allowing all headers to be allowed (`*`).
  const AccessControlAllowHeadersHeader.wildcard()
      : headers = const [],
        isWildcard = true;

  /// Parses the Access-Control-Allow-Headers header value and returns an
  /// [AccessControlAllowHeadersHeader] instance.
  factory AccessControlAllowHeadersHeader.parse(final Iterable<String> values) {
    final splitValues = values.splitTrimAndFilterUnique();
    if (splitValues.isEmpty) {
      throw const FormatException('Value cannot be empty');
    }

    if (splitValues.length == 1 && splitValues.first == '*') {
      return const AccessControlAllowHeadersHeader.wildcard();
    }

    if (splitValues.length > 1 && splitValues.contains('*')) {
      throw const FormatException(
          'Wildcard (*) cannot be used with other headers');
    }

    return AccessControlAllowHeadersHeader.headers(
      headers: splitValues,
    );
  }

  /// Converts the [AccessControlAllowHeadersHeader] instance into a string
  /// representation suitable for HTTP headers.

  String _encode() => isWildcard ? '*' : headers.join(', ');

  @override
  bool operator ==(final Object other) =>
      identical(this, other) ||
      other is AccessControlAllowHeadersHeader &&
          isWildcard == other.isWildcard &&
          const IterableEquality<String>().equals(headers, other.headers);

  @override
  int get hashCode =>
      Object.hash(isWildcard, const IterableEquality<String>().hash(headers));

  @override
  String toString() =>
      'AccessControlAllowHeadersHeader(headers: $headers, isWildcard: $isWildcard)';
}
