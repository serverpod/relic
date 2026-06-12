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
  ///
  /// Per RFC 9110 14.4, `start` and `end` must both be present (a specified
  /// range) or both absent (an `unsatisfied-range`). The `unsatisfied-range`
  /// form requires `size` (the `complete-length`); passing `size: null` with
  /// no range is not representable on the wire.
  ContentRangeHeader({this.unit = 'bytes', this.start, this.end, this.size}) {
    if ((start != null && start! < 0) ||
        (end != null && end! < 0) ||
        (size != null && size! < 0)) {
      throw const FormatException('Content-Range members must not be negative');
    }
    if ((start == null) != (end == null)) {
      throw const FormatException(
        'start and end must both be set or both be null',
      );
    }
    if (start != null && end != null && start! > end!) {
      throw const FormatException('Invalid range');
    }
    if (start == null && end == null && size == null) {
      throw const FormatException(
        'unsatisfied-range form requires a complete-length (size)',
      );
    }
  }

  /// Factory constructor to create a [ContentRangeHeader] from the header string.
  factory ContentRangeHeader.parse(final String value) {
    final trimmed = value.trim();
    if (trimmed.isEmpty) {
      throw const FormatException('Value cannot be empty');
    }

    // Anchored so trailing (or leading) garbage is rejected rather than
    // silently dropped by firstMatch extracting a partial prefix.
    final regex = RegExp(r'^(\w+) (?:(\d+)-(\d+)|\*)/(\*|\d+)$');
    final match = regex.firstMatch(trimmed);

    if (match == null) {
      throw const FormatException('Invalid format');
    }

    final unit = match.group(1)!;
    // The regex guarantees these groups are all digits; parse them with a
    // guard so an overflowing run throws a FormatException instead of
    // int.tryParse silently yielding null (which would turn a specified range
    // into an unsatisfied one) or int.parse throwing an unrelated error.
    final start = _parseField(match.group(2));
    final end = _parseField(match.group(3));
    if (start != null && end != null && start > end) {
      throw const FormatException('Invalid range');
    }
    final sizeGroup = match.group(4)!;
    final size = sizeGroup == '*' ? null : _parseField(sizeGroup);

    return ContentRangeHeader(unit: unit, start: start, end: end, size: size);
  }

  static int? _parseField(final String? digits) {
    if (digits == null) return null;
    final n = int.tryParse(digits);
    if (n == null) {
      throw FormatException('Content-Range value out of range', digits);
    }
    return n;
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
