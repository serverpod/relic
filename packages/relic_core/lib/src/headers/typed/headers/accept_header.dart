import 'dart:typed_data';

import 'package:collection/collection.dart';

import '../../../../relic_core.dart';
import '../primitives/byte_fields.dart';
import '../primitives/byte_scanner.dart' show latin1Bytes;
import 'util/qvalue.dart';

/// A class representing the HTTP Accept header.
///
/// This class manages media ranges and their associated quality values.
final class AcceptHeader {
  static const codec = HeaderCodec.fields(_parseFields, __encode);
  static List<String> __encode(final AcceptHeader value) => [value._encode()];

  /// The list of media ranges accepted by the client.
  final List<MediaRange> mediaRanges;

  /// Constructs an [AcceptHeader] instance with the specified media ranges.
  AcceptHeader.mediaRanges(final List<MediaRange> mediaRanges)
    : assert(mediaRanges.isNotEmpty),
      mediaRanges = List.unmodifiable(mediaRanges);

  /// Takes [mediaRanges], a list the parser built, as its own.
  const AcceptHeader._(this.mediaRanges);

  /// Parses the Accept header [values] and returns an [AcceptHeader]
  /// instance, with the media types and their quality values.
  factory AcceptHeader.parse(final Iterable<String> values) =>
      _parseFields([for (final value in values) latin1Bytes(value)]);

  /// The header from the wire bytes of its [fields].
  static AcceptHeader _parseFields(final List<Uint8List> fields) {
    final elements = splitFieldsUnique(fields);
    if (elements.isEmpty) {
      throw const FormatException('Value cannot be empty');
    }
    return AcceptHeader._(
      List.generate(
        elements.length,
        (final i) => MediaRange._parseBytes(elements[i]),
        growable: false,
      ),
    );
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
  factory MediaRange.parse(final String value) =>
      MediaRange._parseBytes(latin1Bytes(value));

  /// [parse] over the wire bytes of one element.
  static MediaRange _parseBytes(final Uint8List element) {
    // The first non-empty `;` part is the range, the rest its parameters.
    final parts = splitUnique(element, 0x3B);
    if (parts.isEmpty) {
      throw const FormatException('Invalid media range');
    }
    final range = parts.first;
    final slash = indexOfByte(range, 0x2F);
    if (slash < 0 || indexOfByte(range, 0x2F, slash + 1) >= 0) {
      throw const FormatException('Invalid media range');
    }
    final type = textOf(range, 0, trimEnd(range, 0, slash));
    final subtype = textOf(range, trimStart(range, slash + 1, range.length));
    // The parameters as the text path saw them: after the range, with
    // empty and repeated parts dropped.
    final after = indexOfByte(element, 0x3B);
    return MediaRange(
      type,
      subtype,
      quality: after < 0 ? null : qualityParameter(element, after + 1),
    );
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
