import '../../../../relic.dart';

/// A class representing the HTTP Range header.
///
/// This class manages byte ranges, such as `bytes=0-499` or multiple
/// ranges like `bytes=200-999, 2000-2499, 9500-`. It allows clients to
/// request specific parts of a resource. It provides functionality to
/// parse and generate range header values for different range units like
/// bytes or custom units.
final class RangeHeader {
  static const codec = HeaderCodec.single(RangeHeader.parse, __encode);
  static List<String> __encode(final RangeHeader value) => [value._encode()];

  /// The unit of the range (e.g., "bytes").
  final String unit;

  /// The list of ranges specified in the header.
  final List<Range> ranges;

  /// Constructs a [RangeHeader] instance with the specified unit and list
  /// of ranges.
  const RangeHeader({
    this.unit = 'bytes',
    required this.ranges,
  });

  /// Parses the Range header value and returns a [RangeHeader] instance.
  ///
  /// This method processes the range header and extracts the unit and
  /// multiple range values.
  factory RangeHeader.parse(final String value) {
    final trimmed = value.trim();
    if (trimmed.isEmpty) {
      throw const FormatException('Value cannot be empty');
    }

    final regex = RegExp(r'^\s*(\w+)\s*=\s*(.*)$');
    final match = regex.firstMatch(trimmed);

    if (match == null) {
      throw const FormatException('Invalid Range header: invalid format');
    }

    final unit = match.group(1) ?? 'bytes';
    final rangesPart = match.group(2);

    if (rangesPart == null) {
      throw const FormatException('Invalid Range header: missing ranges');
    }

    final rangeStrings = rangesPart.split(',');
    final ranges = rangeStrings.map((final rangeStr) {
      final trimmedRange = rangeStr.trim();
      final rangeMatch = RegExp(r'^(\d*)-(\d*)$').firstMatch(trimmedRange);
      if (rangeMatch == null) {
        throw const FormatException('Invalid range');
      }

      final start = int.tryParse(rangeMatch.group(1) ?? '');
      final end = int.tryParse(rangeMatch.group(2) ?? '');

      if (start == null && end == null) {
        throw const FormatException('Both start and end cannot be empty');
      }

      return Range(start: start, end: end);
    }).toList();

    return RangeHeader(unit: unit, ranges: ranges);
  }

  /// Converts the [RangeHeader] instance into a string representation
  /// suitable for HTTP headers.
  String _encode() {
    final rangesStr = ranges.map((final range) => range._encode()).join(', ');
    return '$unit=$rangesStr';
  }

  @override
  String toString() {
    return 'RangeHeader(unit: $unit, ranges: $ranges)';
  }
}

/// A class representing a single range within a Range header.
class Range {
  /// The start of the range.
  final int? start;

  /// The end of the range.
  final int? end;

  /// Constructs a [Range] instance with the specified start and end of
  /// the range.
  Range({
    this.start,
    this.end,
  }) {
    if (start == null && end == null) {
      throw const FormatException(
          'At least one of start or end must be specified');
    }
  }

  /// Converts the [Range] instance into a string representation suitable
  /// for HTTP headers.
  String _encode() {
    final startStr = start?.toString() ?? '';
    final endStr = end?.toString() ?? '';
    return '$startStr-$endStr';
  }

  @override
  String toString() {
    return 'Range(start: $start, end: $end)';
  }
}
