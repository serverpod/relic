import '../../../../relic_core.dart';

/// A class representing the HTTP Accept-Ranges header.
///
/// This class manages the range units that the server supports.
final class AcceptRangesHeader {
  static const codec = HeaderCodec.single(AcceptRangesHeader.parse, __encode);
  static List<String> __encode(final AcceptRangesHeader value) => [
    value._encode(),
  ];

  /// The range unit supported by the server, or `none` if not supported.
  final String rangeUnit;

  /// Constructs an [AcceptRangesHeader] instance with the specified range unit.
  const AcceptRangesHeader._({required this.rangeUnit});

  /// Constructs an [AcceptRangesHeader] instance with the range unit set to 'none'.
  factory AcceptRangesHeader.none() =>
      const AcceptRangesHeader._(rangeUnit: 'none');

  /// Constructs an [AcceptRangesHeader] instance with the range unit set to 'bytes'.
  factory AcceptRangesHeader.bytes() =>
      const AcceptRangesHeader._(rangeUnit: 'bytes');

  /// Parses the Accept-Ranges header value and returns an [AcceptRangesHeader] instance.
  ///
  /// This method processes the header value, extracting the range unit.
  factory AcceptRangesHeader.parse(final String value) {
    final trimmed = value.trim();
    if (trimmed.isEmpty) {
      throw const FormatException('Value cannot be empty');
    }

    return AcceptRangesHeader._(rangeUnit: trimmed);
  }

  /// Returns `true` if the range unit is 'bytes', otherwise `false`.
  bool get isBytes => rangeUnit == 'bytes';

  /// Returns `true` if the range unit is 'none' or `null`, otherwise `false`.
  bool get isNone => rangeUnit == 'none';

  /// Converts the [AcceptRangesHeader] instance into a string representation suitable for HTTP headers.

  String _encode() => rangeUnit;

  @override
  bool operator ==(final Object other) =>
      identical(this, other) ||
      other is AcceptRangesHeader && rangeUnit == other.rangeUnit;

  @override
  int get hashCode => rangeUnit.hashCode;

  @override
  String toString() {
    return 'AcceptRangesHeader(rangeUnit: $rangeUnit)';
  }
}
