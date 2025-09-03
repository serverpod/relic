import '../../../../relic.dart';

/// A class representing the HTTP Access-Control-Allow-Origin header.
///
/// This header specifies which origins are allowed to access the resource.
/// It can be a specific origin or a wildcard (`*`) to allow any origin.
final class AccessControlAllowOriginHeader {
  static const codec =
      HeaderCodec.single(AccessControlAllowOriginHeader.parse, __encode);
  static List<String> __encode(final AccessControlAllowOriginHeader value) =>
      [value._encode()];

  /// The allowed origin URI, if specified.
  final Uri? origin;

  /// Whether any origin is allowed (`*`).
  final bool isWildcard;

  /// Constructs an instance allowing a specific origin.
  const AccessControlAllowOriginHeader.origin({required this.origin})
      : isWildcard = false;

  /// Constructs an instance allowing any origin (`*`).
  const AccessControlAllowOriginHeader.wildcard()
      : origin = null,
        isWildcard = true;

  /// Parses the Access-Control-Allow-Origin header value and
  /// returns an [AccessControlAllowOriginHeader] instance.
  ///
  /// This method checks if the value is a wildcard or a specific origin.
  factory AccessControlAllowOriginHeader.parse(final String value) {
    final trimmed = value.trim();
    if (trimmed.isEmpty) {
      throw const FormatException('Value cannot be empty');
    }

    if (trimmed == '*') {
      return const AccessControlAllowOriginHeader.wildcard();
    }

    try {
      return AccessControlAllowOriginHeader.origin(
        origin: Uri.parse(trimmed),
      );
    } catch (_) {
      throw const FormatException('Invalid URI format');
    }
  }

  /// Converts the [AccessControlAllowOriginHeader] instance into a string
  /// representation suitable for HTTP headers.

  String _encode() => isWildcard ? '*' : origin.toString();

  @override
  bool operator ==(final Object other) =>
      identical(this, other) ||
      other is AccessControlAllowOriginHeader &&
          isWildcard == other.isWildcard &&
          origin == other.origin;

  @override
  int get hashCode => Object.hash(isWildcard, origin);

  @override
  String toString() =>
      'AccessControlAllowOriginHeader(origin: $origin, isWildcard: $isWildcard)';
}
