import '../../../../relic_core.dart';

/// The HTTP `Access-Control-Allow-Origin` response header.
///
/// Per the WHATWG Fetch Standard, the value is exactly one of:
///
/// * `*` (the wildcard - any origin is allowed; not usable with credentials).
/// * `null` (the opaque-origin sentinel - e.g. for sandboxed `iframe`s).
/// * A serialized origin (`scheme://host[:port]`).
///
/// A list of origins is *not* legal here, regardless of how some servers
/// behave in the wild. Trailing slashes, paths, queries, and fragments are
/// also rejected.
final class AccessControlAllowOriginHeader {
  static const codec = HeaderCodec.single(
    AccessControlAllowOriginHeader.parse,
    __encode,
  );
  static List<String> __encode(final AccessControlAllowOriginHeader value) => [
    value._encode(),
  ];

  /// The allowed origin, or `null` when this header is the wildcard `*`.
  ///
  /// A value of [OpaqueOrigin.instance] represents the `null` wire token (an
  /// opaque origin) - which is distinct from this field itself being `null`
  /// (the wildcard).
  final Origin? origin;

  /// Whether this header value is the wildcard `*` (any origin).
  bool get isWildcard => origin == null;

  /// Constructs an instance allowing the given [origin].
  const AccessControlAllowOriginHeader.origin({required Origin this.origin});

  /// Constructs an instance allowing any origin (`*`).
  const AccessControlAllowOriginHeader.wildcard() : origin = null;

  /// Parses the `Access-Control-Allow-Origin` header value and returns an
  /// [AccessControlAllowOriginHeader] instance.
  ///
  /// Throws [FormatException] if [value] is empty or is not a valid origin
  /// per [Origin.parse].
  factory AccessControlAllowOriginHeader.parse(final String value) {
    final trimmed = value.trim();
    if (trimmed.isEmpty) {
      throw const FormatException('Value cannot be empty');
    }
    if (trimmed == '*') {
      return const AccessControlAllowOriginHeader.wildcard();
    }
    return AccessControlAllowOriginHeader.origin(origin: Origin.parse(trimmed));
  }

  String _encode() => origin?.encode() ?? '*';

  @override
  bool operator ==(final Object other) =>
      identical(this, other) ||
      other is AccessControlAllowOriginHeader && origin == other.origin;

  @override
  // The wildcard (`origin == null`) gets a distinct sentinel hash so it does
  // not share bucket 0 with an opaque-origin value.
  int get hashCode => origin?.hashCode ?? 0x2A; // '*'

  @override
  String toString() => 'AccessControlAllowOriginHeader($origin)';
}
