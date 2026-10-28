import 'dart:typed_data';

import 'package:meta/meta.dart';

import 'byte_fields.dart';

/// An HTTP entity-tag per [RFC 9110 section 8.8.3][rfc-etag].
///
///     entity-tag  = [ weak ] opaque-tag
///     weak        = %s"W/"           ; case-sensitive
///     opaque-tag  = DQUOTE *etagc DQUOTE
///     etagc       = %x21 / %x23-7E / obs-text
///                   ; VCHAR minus DQUOTE, plus obs-text
///
/// Used by `ETag`, `If-Match`, `If-None-Match`, and `If-Range`.
///
/// [value] stores the unescaped opaque-tag contents (the bytes between the
/// two `"` characters). [isWeak] reflects the leading `W/` marker.
///
/// [rfc-etag]: https://datatracker.ietf.org/doc/html/rfc9110#section-8.8.3
@immutable
final class ETagValue {
  /// The opaque-tag characters as they appear between the quotes on the
  /// wire. Validated against `etagc` at construction.
  final String value;

  /// True if this entity-tag carries the `W/` weak marker.
  final bool isWeak;

  /// Creates an [ETagValue] from its parts.
  ///
  /// Throws [FormatException] if [value] contains any character outside the
  /// `etagc` grammar (notably `"` and CTL characters).
  ETagValue({required this.value, this.isWeak = false}) {
    for (var i = 0; i < value.length; i++) {
      if (!_isEtagc(value.codeUnitAt(i))) {
        throw FormatException(
          'invalid character in ETag opaque-tag (RFC 9110 8.8.3)',
          value,
          i,
        );
      }
    }
  }

  /// Parses [source] as `[ "W/" ] DQUOTE *etagc DQUOTE` per RFC 9110 8.8.3.
  ///
  /// The `W/` prefix is matched case-sensitively. The opaque-tag must be
  /// quoted; surrounding whitespace is not allowed (callers should strip it
  /// at the field level).
  factory ETagValue.parse(final String source) {
    final bytes = Uint8List(source.length);
    for (var i = 0; i < source.length; i++) {
      final c = source.codeUnitAt(i);
      // A code unit no byte can be fails the etagc check below, as it did.
      bytes[i] = c > 0xFF ? 0x7F : c;
    }
    return ETagValue.parseBytes(bytes);
  }

  /// [parse] over the wire bytes.
  factory ETagValue.parseBytes(final Uint8List source) {
    var i = 0;
    var weak = false;
    if (source.length >= 2 && source[0] == 0x57 && source[1] == 0x2F) {
      // W/
      weak = true;
      i = 2;
    }
    if (i >= source.length || source[i] != _dquote) {
      throw FormatException('expected opening DQUOTE', textOf(source), i);
    }
    if (source.length - i < 2 || source[source.length - 1] != _dquote) {
      throw FormatException('unterminated opaque-tag', textOf(source));
    }
    return ETagValue(
      value: textOf(source, i + 1, source.length - 1),
      isWeak: weak,
    );
  }

  /// The wire form: `[ "W/" ] DQUOTE value DQUOTE`.
  String encode() => isWeak ? 'W/"$value"' : '"$value"';

  /// Strong comparison per RFC 9110 8.8.3.2: equal iff both are strong and
  /// have the same opaque-tag. Suitable for cache validation of
  /// representations that must be byte-identical.
  bool strongMatches(final ETagValue other) =>
      !isWeak && !other.isWeak && value == other.value;

  /// Weak comparison per RFC 9110 8.8.3.2: equal iff the opaque-tags match,
  /// regardless of either tag's weak marker.
  bool weakMatches(final ETagValue other) => value == other.value;

  @override
  bool operator ==(final Object other) =>
      identical(this, other) ||
      (other is ETagValue && value == other.value && isWeak == other.isWeak);

  @override
  int get hashCode => Object.hash(value, isWeak);

  @override
  String toString() => encode();
}

const int _dquote = 0x22;

bool _isEtagc(final int c) {
  if (c == 0x21) return true;
  if (c >= 0x23 && c <= 0x7E) return true; // VCHAR minus DQUOTE
  if (c >= 0x80 && c <= 0xFF) return true; // obs-text
  return false;
}
