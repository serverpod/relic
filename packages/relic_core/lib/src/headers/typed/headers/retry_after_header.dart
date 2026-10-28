import 'dart:typed_data';

import 'package:http_parser/http_parser.dart';
import '../../../../relic_core.dart';
import '../primitives/byte_fields.dart';
import '../primitives/byte_scanner.dart' show latin1Bytes;

/// A class representing the HTTP Retry-After header.
///
/// This class manages both date-based and delay-based retry values.
/// The Retry-After header can contain either an HTTP date or a delay in seconds
/// indicating when the client should retry the request.
final class RetryAfterHeader {
  static const codec = HeaderCodec.bytes(_parseBytes, __encode);
  static List<String> __encode(final RetryAfterHeader value) => [
    value._encode(),
  ];

  /// The retry delay in seconds, if present.
  final int? delay;

  /// The retry date, if present.
  final DateTime? date;

  /// Constructs a [RetryAfterHeader] instance with either a delay in seconds or a date.
  RetryAfterHeader({this.delay, this.date}) {
    if (delay == null && date == null) {
      throw const FormatException('Either delay or date must be specified');
    }
    if (delay != null && date != null) {
      throw const FormatException(
        'Both delay and date cannot be specified at the same time',
      );
    }
  }

  /// Parses the Retry-After header value and returns a [RetryAfterHeader] instance.
  ///
  /// This method checks if the value is an integer (for delay) or a date string.
  factory RetryAfterHeader.parse(final String value) =>
      _parseBytes(latin1Bytes(value));

  /// [parse] over the wire bytes.
  ///
  /// A numeric value is a delay (`delta-seconds = 1*DIGIT`). A leading
  /// sign is rejected: `-120` is negative and `+120` is not a valid
  /// delta-seconds.
  static RetryAfterHeader _parseBytes(final Uint8List bytes) {
    final value = trimmed(bytes);
    if (value.isEmpty) {
      throw const FormatException('Value cannot be empty');
    }
    final signed = value[0] == 0x2B || value[0] == 0x2D;
    var digits = signed ? 1 : 0;
    while (digits < value.length &&
        value[digits] >= 0x30 &&
        value[digits] <= 0x39) {
      digits++;
    }
    if (digits == value.length && digits > (signed ? 1 : 0)) {
      if (value[0] == 0x2D) {
        throw const FormatException('Delay cannot be negative');
      }
      return RetryAfterHeader(delay: DeltaSeconds.parse(textOf(value)).seconds);
    }
    try {
      return RetryAfterHeader(date: parseHttpDate(textOf(value)));
    } catch (e) {
      throw const FormatException('Invalid date format');
    }
  }

  /// Converts the [RetryAfterHeader] instance into a string representation
  /// suitable for HTTP headers.

  String _encode() {
    if (delay != null) {
      return delay.toString();
    }
    if (date != null) {
      return formatHttpDate(date!);
    }
    return '';
  }

  @override
  bool operator ==(final Object other) =>
      identical(this, other) ||
      other is RetryAfterHeader && delay == other.delay && date == other.date;

  @override
  int get hashCode => Object.hash(delay, date);

  @override
  String toString() {
    return 'RetryAfterHeader(delay: $delay, date: $date)';
  }
}
