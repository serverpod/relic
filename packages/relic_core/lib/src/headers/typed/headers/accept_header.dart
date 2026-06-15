import 'package:collection/collection.dart';

import '../../../../relic_core.dart';
import '../../extension/string_list_extensions.dart';
import 'util/qvalue.dart';

/// A class representing the HTTP Accept header.
///
/// This class manages media ranges and their associated quality values.
final class AcceptHeader {
  static const codec = HeaderCodec(AcceptHeader.parse, __encode);
  static List<String> __encode(final AcceptHeader value) => [value._encode()];

  /// The list of media ranges accepted by the client.
  final List<MediaRange> mediaRanges;

  /// Constructs an [AcceptHeader] instance with the specified media ranges.
  AcceptHeader.mediaRanges(final List<MediaRange> mediaRanges)
    : assert(mediaRanges.isNotEmpty),
      mediaRanges = List.unmodifiable(mediaRanges);

  /// Parses the Accept header value and returns an [AcceptHeader] instance.
  ///
  /// This method processes the header value, extracting media types and
  /// their quality values.
  factory AcceptHeader.parse(final Iterable<String> values) {
    final splitValues = values.splitTrimAndFilterUnique();
    if (splitValues.isEmpty) {
      throw const FormatException('Value cannot be empty');
    }

    final mediaRanges = splitValues.map(MediaRange.parse).toList();

    return AcceptHeader.mediaRanges(mediaRanges);
  }

  /// Converts the [AcceptHeader] instance into a string representation suitable for HTTP headers.
  String _encode() => mediaRanges.map((final mr) => mr._encode()).join(', ');

  @override
  bool operator ==(final Object other) =>
      identical(this, other) ||
      other is AcceptHeader &&
          const ListEquality<MediaRange>().equals(
            mediaRanges,
            other.mediaRanges,
          );

  @override
  int get hashCode => const ListEquality<MediaRange>().hash(mediaRanges);

  @override
  String toString() => 'AcceptHeader(mediaRanges: $mediaRanges)';
}

/// A class representing a media range with an optional quality value.
class MediaRange {
  /// The type of the media (e.g., "text").
  final String type;

  /// The subtype of the media (e.g., "html").
  final String subtype;

  /// The quality value (default is 1.0).
  final double quality;

  /// Constructs a [MediaRange] instance with the specified type, subtype,
  /// quality, and parameters.
  MediaRange(this.type, this.subtype, {final double? quality})
    : quality = quality ?? 1.0;

  /// Parses a media range string and returns a [MediaRange] instance.
  ///
  /// Parameters are split on `;` (RFC 9110 12.5.1 `parameters`), and the
  /// quality value `q=...` is matched by parameter name (case-insensitive,
  /// surrounded by OWS) per RFC 9110 12.4.2 - not by a literal `q=`
  /// substring, which silently misparses any input with whitespace around
  /// the semicolon.
  factory MediaRange.parse(final String value) {
    final parts = value.splitTrimAndFilterUnique(separator: ';').toList();
    final typeSubtype = parts.first.split('/');
    if (typeSubtype.length != 2) {
      throw const FormatException('Invalid media range');
    }

    final type = typeSubtype[0].trim();
    final subtype = typeSubtype[1].trim();

    double? quality;
    for (var i = 1; i < parts.length; i++) {
      final eq = parts[i].indexOf('=');
      if (eq < 0) continue;
      final name = parts[i].substring(0, eq).trim();
      if (name.toLowerCase() != 'q') continue;
      final parsed = double.tryParse(parts[i].substring(eq + 1).trim());
      // A malformed or out-of-range weight is treated as absent (defaulting to
      // 1.0) rather than rejecting the whole header: the client did list this
      // entry, so it is acceptable; only the unparseable preference is dropped
      // (RFC 9110 12.4.2; robustness on received headers).
      if (parsed != null && parsed >= 0 && parsed <= 1) {
        quality = parsed;
      }
      break;
    }

    return MediaRange(type, subtype, quality: quality);
  }

  /// Converts the [MediaRange] instance into a string representation suitable
  /// for HTTP headers. The q-value is rendered with at most 3 fractional
  /// digits per RFC 9110 12.4.2 (`qvalue = ( "0" [ "." 0*3DIGIT ] ) / ...`).
  String _encode() {
    final qualityStr = quality == 1.0 ? '' : ';q=${formatQValue(quality)}';
    return '$type/$subtype$qualityStr';
  }

  @override
  bool operator ==(final Object other) =>
      identical(this, other) ||
      other is MediaRange &&
          type == other.type &&
          subtype == other.subtype &&
          quality == other.quality;

  @override
  int get hashCode => Object.hash(type, subtype, quality);

  @override
  String toString() =>
      'MediaRange(type: $type, subtype: $subtype, quality: $quality)';
}
