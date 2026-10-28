import 'dart:typed_data';

import 'package:collection/collection.dart';

import '../../../../relic_core.dart';
import '../primitives/byte_fields.dart';
import '../primitives/byte_scanner.dart' show latin1Bytes;

/// A class representing the HTTP Range header.
///
/// This class manages byte ranges, such as `bytes=0-499` or multiple
/// ranges like `bytes=200-999, 2000-2499, 9500-`. It allows clients to
/// request specific parts of a resource. It provides functionality to
/// parse and generate range header values for different range units like
/// bytes or custom units.
final class RangeHeader {
  static const codec = HeaderCodec.bytes(_parseBytes, __encode);
  static List<String> __encode(final RangeHeader value) => [value._encode()];

  /// The unit of the range (e.g., "bytes").
  final String unit;

  /// The list of ranges specified in the header.
  final List<Range> ranges;

  /// Constructs a [RangeHeader] instance with the specified unit and list
  /// of ranges.
  RangeHeader({this.unit = 'bytes', required this.ranges})
    : assert(ranges.isNotEmpty);

  /// Parses the Range header value and returns a [RangeHeader] instance.
  ///
  /// This method processes the range header and extracts the unit and
  /// multiple range values.
  factory RangeHeader.parse(final String value) =>
      _parseBytes(latin1Bytes(value));

  /// [parse] over the wire bytes: `unit "=" ranges`, each range
  /// `[first] "-" [last]` with at least one side.
  static RangeHeader _parseBytes(final Uint8List bytes) {
    final value = trimmed(bytes);
    if (value.isEmpty) {
      throw const FormatException('Value cannot be empty');
    }
    final length = value.length;
    var i = 0;
    while (i < length && _isWordByte(value[i])) {
      i++;
    }
    if (i == 0) {
      throw const FormatException('Invalid Range header: invalid format');
    }
    final unit = textOf(value, 0, i);
    i = trimStart(value, i, length);
    if (i >= length || value[i] != 0x3D) {
      throw const FormatException('Invalid Range header: invalid format');
    }
    final rangesStart = trimStart(value, i + 1, length);
    final ranges = <Range>[];
    var start = rangesStart;
    while (start <= length) {
      var end = indexOfByte(value, 0x2C, start, length);
      final next = end < 0 ? length + 1 : end + 1;
      if (end < 0) end = length;
      final s = trimStart(value, start, end);
      final e = trimEnd(value, s, end);
      final dash = indexOfByte(value, 0x2D, s, e);
      if (dash < 0 ||
          _digitsEnd(value, s) != dash ||
          _digitsEnd(value, dash + 1) != e) {
        throw const FormatException('Invalid range');
      }
      final first = dash == s ? null : int.tryParse(textOf(value, s, dash));
      final last = dash + 1 == e
          ? null
          : int.tryParse(textOf(value, dash + 1, e));
      if (first == null && last == null) {
        throw const FormatException('Both start and end cannot be empty');
      }
      ranges.add(Range(start: first, end: last));
      start = next;
    }
    return RangeHeader(unit: unit, ranges: ranges);
  }

  /// The end of the run of ASCII digits at [from], up to [bytes] length.
  static int _digitsEnd(final Uint8List bytes, int from) {
    while (from < bytes.length && bytes[from] >= 0x30 && bytes[from] <= 0x39) {
      from++;
    }
    return from;
  }

  /// A letter, digit or underscore, what `\w` matches.
  static bool _isWordByte(final int b) =>
      (b >= 0x30 && b <= 0x39) ||
      (b >= 0x41 && b <= 0x5A) ||
      (b >= 0x61 && b <= 0x7A) ||
      b == 0x5F;

  /// Converts the [RangeHeader] instance into a string representation
  /// suitable for HTTP headers.
  String _encode() {
    final rangesStr = ranges.map((final range) => range._encode()).join(', ');
    return '$unit=$rangesStr';
  }

  @override
  bool operator ==(final Object other) =>
      identical(this, other) ||
      other is RangeHeader &&
          unit == other.unit &&
          const ListEquality<Range>().equals(ranges, other.ranges);

  @override
  int get hashCode =>
      Object.hash(unit, const ListEquality<Range>().hash(ranges));

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
  Range({this.start, this.end}) {
    if (start == null && end == null) {
      throw const FormatException(
        'At least one of start or end must be specified',
      );
    }
    // An inverted range (last-pos < first-pos) is represented faithfully
    // rather than rejected. RFC 9110 14.2 has the recipient ignore or answer
    // 416 for a range it cannot satisfy, so satisfiability against a concrete
    // resource is the consumer's call (e.g. a file handler returning 416),
    // not the parser's.
  }

  /// Converts the [Range] instance into a string representation suitable
  /// for HTTP headers.
  String _encode() {
    final startStr = start?.toString() ?? '';
    final endStr = end?.toString() ?? '';
    return '$startStr-$endStr';
  }

  @override
  bool operator ==(final Object other) =>
      identical(this, other) ||
      other is Range && start == other.start && end == other.end;

  @override
  int get hashCode => Object.hash(start, end);

  @override
  String toString() {
    return 'Range(start: $start, end: $end)';
  }
}
