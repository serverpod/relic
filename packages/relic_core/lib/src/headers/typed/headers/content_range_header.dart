import '../../../../relic_core.dart';

/// A class representing an HTTP Content-Range header for byte ranges.
///
/// This class is used to manage byte ranges in HTTP requests or responses,
/// including cases for unsatisfiable range requests.
final class ContentRangeHeader {
  static const codec = HeaderCodec.single(ContentRangeHeader.parse, __encode);
  static List<String> __encode(final ContentRangeHeader value) => [
    value._encode(),
  ];

  /// The unit of the range, e.g. "bytes".
  final String unit;

  /// The start of the byte range, or `null` if this is an unsatisfiable range.
  final int? start;

  /// The end of the byte range, or `null` if this is an unsatisfiable range.
  final int? end;

  /// The total size of the resource being ranged, or `null` if unknown.
  final int? size;

  /// Constructs a [ContentRangeHeader] with the specified range and optional total size.
  ContentRangeHeader({this.unit = 'bytes', this.start, this.end, this.size}) {
    if (start != null && end != null && start! > end!) {
      throw const FormatException('Invalid range');
    }
  }

  /// Factory constructor to create a [ContentRangeHeader] from the header string.
  factory ContentRangeHeader.parse(final String value) {
    final trimmed = value.trim();
    if (trimmed.isEmpty) {
      throw const FormatException('Value cannot be empty');
    }

    final regex = RegExp(r'(\w+) (?:(\d+)-(\d+)|\*)/(\*|\d+)');
    final match = regex.firstMatch(trimmed);

    if (match == null) {
      throw const FormatException('Invalid format');
    }

    final unit = match.group(1)!;
    final start = match.group(2) != null ? int.tryParse(match.group(2)!) : null;
    final end = match.group(3) != null ? int.tryParse(match.group(3)!) : null;
    if (start != null && end != null && start > end) {
      throw const FormatException('Invalid range');
    }
    final sizeGroup = match.group(4)!;

    // If totalSize is '*', it means the total size is unknown
    final size = sizeGroup == '*' ? null : int.parse(sizeGroup);

    return ContentRangeHeader(unit: unit, start: start, end: end, size: size);
  }

  /// Returns the full content range string in the format "bytes start-end/totalSize".
  ///
  /// If the total size is unknown, it uses "*" in place of the total size.

  String _encode() {
    final sizeStr = size?.toString() ?? '*';
    if (start == null && end == null) {
      return '$unit */$sizeStr';
    }
    return '$unit $start-$end/$sizeStr';
  }

  @override
  bool operator ==(final Object other) =>
      identical(this, other) ||
      other is ContentRangeHeader &&
          unit == other.unit &&
          start == other.start &&
          end == other.end &&
          size == other.size;

  @override
  int get hashCode => Object.hash(unit, start, end, size);

  @override
  String toString() {
    return 'ContentRangeHeader(unit: $unit, start: $start, end: $end, size: $size)';
  }
}
