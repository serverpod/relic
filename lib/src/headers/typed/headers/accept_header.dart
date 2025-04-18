import '../../../../relic.dart';
import '../../extension/string_list_extensions.dart';

/// A class representing the HTTP Accept header.
///
/// This class manages media ranges and their associated quality values.
final class AcceptHeader {
  static const codec = HeaderCodec(AcceptHeader.parse, __encode);
  static List<String> __encode(final AcceptHeader value) => [value._encode()];

  /// The list of media ranges accepted by the client.
  final List<MediaRange> mediaRanges;

  /// Constructs an [AcceptHeader] instance with the specified media ranges.
  const AcceptHeader({required this.mediaRanges});

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

    return AcceptHeader(mediaRanges: mediaRanges);
  }

  /// Converts the [AcceptHeader] instance into a string representation suitable for HTTP headers.
  String _encode() => mediaRanges.map((final mr) => mr._encode()).join(', ');

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
  /// This method processes the media range string, extracting the type,
  /// subtype, quality, and parameters.
  factory MediaRange.parse(final String value) {
    final parts = value.splitTrimAndFilterUnique(separator: ';').toList();
    final typeSubtype = parts.first.split('/');
    if (typeSubtype.length != 2) {
      throw const FormatException('Invalid media range');
    }

    final type = typeSubtype[0].trim();
    final subtype = typeSubtype[1].trim();

    double? quality;
    if (parts.length > 1) {
      final qualityParts =
          parts[1].splitTrimAndFilterUnique(separator: 'q=').firstOrNull;
      if (qualityParts != null) {
        final value = double.tryParse(qualityParts);
        if (value == null || value < 0 || value > 1) {
          throw const FormatException('Invalid quality value');
        }
        quality = value;
      }
    }

    return MediaRange(
      type,
      subtype,
      quality: quality,
    );
  }

  /// Converts the [MediaRange] instance into a string representation suitable for HTTP headers.
  String _encode() {
    final qualityStr = quality == 1.0 ? '' : ';q=$quality';
    return '$type/$subtype$qualityStr';
  }

  @override
  String toString() =>
      'MediaRange(type: $type, subtype: $subtype, quality: $quality)';
}
