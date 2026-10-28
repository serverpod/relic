import 'dart:typed_data';

import '../../../../relic_core.dart';
import '../primitives/byte_fields.dart';
import '../primitives/byte_scanner.dart' show latin1Bytes;

/// A class representing an HTTP Content-Range header for byte ranges.
///
/// This class is used to manage byte ranges in HTTP requests or responses,
/// including cases for unsatisfiable range requests.
final class ContentRangeHeader {
  static const codec = HeaderCodec.bytes(_parseBytes, __encode);
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
  factory ContentRangeHeader.parse(final String value) =>
      _parseBytes(latin1Bytes(value));

  /// [parse] over the wire bytes: `unit SP ( first "-" last / "*" ) "/"
  /// ( complete-length / "*" )`, with nothing before or after, so
  /// trailing garbage is rejected rather than dropped.
  static ContentRangeHeader _parseBytes(final Uint8List bytes) {
    final value = trimmed(bytes);
    if (value.isEmpty) {
      throw const FormatException('Value cannot be empty');
    }
    final length = value.length;
    var i = 0;
    while (i < length && _isWordByte(value[i])) {
      i++;
    }
    if (i == 0 || i >= length || value[i] != 0x20) {
      throw const FormatException('Invalid format');
    }
    final unit = textOf(value, 0, i);
    i++;
    int? start;
    int? end;
    if (i < length && value[i] == 0x2A) {
      i++;
    } else {
      final startEnd = _digitsEnd(value, i);
      if (startEnd == i || startEnd >= length || value[startEnd] != 0x2D) {
        throw const FormatException('Invalid format');
      }
      final lastEnd = _digitsEnd(value, startEnd + 1);
      if (lastEnd == startEnd + 1) {
        throw const FormatException('Invalid format');
      }
      start = _parseField(textOf(value, i, startEnd));
      end = _parseField(textOf(value, startEnd + 1, lastEnd));
      i = lastEnd;
    }
    if (i >= length || value[i] != 0x2F) {
      throw const FormatException('Invalid format');
    }
    i++;
    int? size;
    if (i < length && value[i] == 0x2A) {
      i++;
    } else {
      final sizeEnd = _digitsEnd(value, i);
      if (sizeEnd == i) {
        throw const FormatException('Invalid format');
      }
      size = _parseField(textOf(value, i, sizeEnd));
      i = sizeEnd;
    }
    if (i != length) {
      throw const FormatException('Invalid format');
    }
    if (start != null && end != null && start > end) {
      throw const FormatException('Invalid range');
    }
    return ContentRangeHeader(unit: unit, start: start, end: end, size: size);
  }

  /// The end of the run of ASCII digits at [from].
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

  /// The digits as an int, or a [FormatException] for a run that
  /// overflows, so a specified range never turns into an unsatisfied one.
  static int _parseField(final String digits) {
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
