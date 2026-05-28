import 'package:meta/meta.dart';

import 'host.dart';

/// A Web origin, as defined by the WHATWG Fetch Standard and RFC 6454.
///
/// An origin is either:
///
/// * [OpaqueOrigin] - the literal byte string `null`, used for opaque origins
///   such as sandboxed `iframe`s, `data:` URLs, and `file:` resources. This
///   is a distinct case from "no origin"; the wire form is the bare token
///   `null` (without quotes).
/// * [TupleOrigin] - a `scheme://host[:port]` triple. The serialized form has
///   no trailing slash, no path, no query, and no fragment.
///
/// `Access-Control-Allow-Origin` is the canonical example of a header whose
/// value is exactly one [Origin] (or the wildcard `*`, which is *not* an
/// origin and lives outside this type).
sealed class Origin {
  const Origin();

  /// Parses [source] as an origin.
  ///
  /// Accepts:
  /// * The literal `null` (returns the [OpaqueOrigin] sentinel).
  /// * `scheme://host[:port]` (returns a [TupleOrigin]).
  ///
  /// Rejects any input with a path, query, or fragment.
  factory Origin.parse(final String source) {
    if (source == 'null') return OpaqueOrigin.instance;

    final schemeEnd = source.indexOf('://');
    if (schemeEnd < 0) {
      throw FormatException('expected "scheme://host[:port]"', source);
    }
    final scheme = source.substring(0, schemeEnd);
    final rest = source.substring(schemeEnd + 3);
    if (rest.isEmpty) {
      throw FormatException('missing host', source);
    }

    var inBracket = false;
    for (var i = 0; i < rest.length; i++) {
      final c = rest.codeUnitAt(i);
      if (c == 0x5B) {
        inBracket = true;
        continue;
      }
      if (c == 0x5D) {
        inBracket = false;
        continue;
      }
      if (inBracket) continue;
      // A serialized origin is scheme "://" host [ ":" port ] only: no
      // path/query/fragment, no userinfo, and no controls or whitespace.
      if (c == 0x2F || c == 0x3F || c == 0x23) {
        throw FormatException(
          'origin must not include path, query, or fragment',
          source,
          schemeEnd + 3 + i,
        );
      }
      if (c == 0x40) {
        throw FormatException(
          'origin must not include userinfo',
          source,
          schemeEnd + 3 + i,
        );
      }
      if (c <= 0x20 || c == 0x7F) {
        throw FormatException(
          'origin must not contain control characters or whitespace',
          source,
          schemeEnd + 3 + i,
        );
      }
    }

    return TupleOrigin(scheme: scheme, host: Host.parse(rest));
  }

  /// The wire form of this origin.
  String encode();
}

/// The opaque origin sentinel, serialized as `null`.
final class OpaqueOrigin extends Origin {
  const OpaqueOrigin._();

  /// The canonical instance. Use this rather than allocating a new one each
  /// time.
  static const OpaqueOrigin instance = OpaqueOrigin._();

  @override
  String encode() => 'null';

  @override
  bool operator ==(final Object other) => other is OpaqueOrigin;

  @override
  // A fixed non-zero hash for the single opaque-origin value. Non-zero so it
  // does not collide with the common `null`/0 bucket (e.g. an Allow-Origin
  // wildcard whose origin is null).
  int get hashCode => 0x09A9;

  @override
  String toString() => 'null';
}

/// A `scheme://host[:port]` origin tuple per RFC 6454.
@immutable
final class TupleOrigin extends Origin {
  /// The URI scheme, validated against the RFC 3986 grammar and stored in
  /// ASCII-lowercase form (schemes are case-insensitive).
  final String scheme;

  /// The host component.
  final Host host;

  /// Creates a [TupleOrigin] from its parts.
  ///
  /// Throws [FormatException] if [scheme] is empty or does not match
  /// `ALPHA *( ALPHA / DIGIT / "+" / "-" / "." )` (RFC 3986 3.1).
  TupleOrigin({required final String scheme, required this.host})
    : scheme = _validateScheme(scheme);

  @override
  String encode() => '$scheme://${host.encode()}';

  @override
  bool operator ==(final Object other) =>
      identical(this, other) ||
      (other is TupleOrigin && scheme == other.scheme && host == other.host);

  @override
  int get hashCode => Object.hash(scheme, host);

  @override
  String toString() => encode();
}

String _validateScheme(final String s) {
  if (s.isEmpty) {
    throw const FormatException('scheme cannot be empty');
  }
  final c0 = s.codeUnitAt(0);
  if (!_isAlpha(c0)) {
    throw FormatException('scheme must start with ALPHA', s, 0);
  }
  for (var i = 1; i < s.length; i++) {
    final c = s.codeUnitAt(i);
    if (!_isAlpha(c) &&
        !_isDigit(c) &&
        c != 0x2B && // +
        c != 0x2D && // -
        c != 0x2E) {
      // .
      throw FormatException('invalid character in scheme', s, i);
    }
  }
  return s.toLowerCase();
}

bool _isAlpha(final int c) =>
    (c >= 0x41 && c <= 0x5A) || (c >= 0x61 && c <= 0x7A);
bool _isDigit(final int c) => c >= 0x30 && c <= 0x39;
