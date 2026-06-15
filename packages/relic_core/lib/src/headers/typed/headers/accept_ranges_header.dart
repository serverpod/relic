import 'package:collection/collection.dart';

import '../../../../relic_core.dart';

/// A class representing the HTTP Accept-Ranges header.
///
/// Per RFC 9110 14.3, `Accept-Ranges = acceptable-ranges` where
/// `acceptable-ranges = 1#range-unit` (a comma-separated list). The legacy
/// value `none` indicates the server does not support range requests.
final class AcceptRangesHeader {
  static const codec = HeaderCodec.single(AcceptRangesHeader.parse, __encode);
  static List<String> __encode(final AcceptRangesHeader value) => [
    value._encode(),
  ];

  /// The range units supported by the server (canonical lowercase tokens).
  final List<String> rangeUnits;

  /// Constructs an [AcceptRangesHeader] with the given range units.
  const AcceptRangesHeader._(this.rangeUnits);

  /// Constructs an [AcceptRangesHeader] signalling no range support (`none`).
  factory AcceptRangesHeader.none() => const AcceptRangesHeader._(['none']);

  /// Constructs an [AcceptRangesHeader] supporting byte ranges (`bytes`).
  factory AcceptRangesHeader.bytes() => const AcceptRangesHeader._(['bytes']);

  /// Parses the Accept-Ranges header value as `1#range-unit`.
  factory AcceptRangesHeader.parse(final String value) {
    final units = value
        .split(',')
        .map((final u) => u.trim())
        .where((final u) => u.isNotEmpty)
        .map((final u) => Token.validate(u).toLowerCase())
        .toList();
    if (units.isEmpty) {
      throw const FormatException('Value cannot be empty');
    }
    // `none` is the no-range-support sentinel; combining it with real range
    // units (e.g. `bytes, none`) is contradictory and is rejected so isBytes /
    // isNone cannot both hold.
    if (units.contains('none') && units.length > 1) {
      throw const FormatException(
        'Accept-Ranges "none" must not be combined with other range units',
      );
    }
    return AcceptRangesHeader._(List.unmodifiable(units));
  }

  /// Returns `true` if `bytes` is among the supported range units.
  bool get isBytes => rangeUnits.contains('bytes');

  /// Returns `true` if the header is exactly the `none` no-support signal.
  bool get isNone => rangeUnits.length == 1 && rangeUnits.first == 'none';

  String _encode() => rangeUnits.join(', ');

  @override
  bool operator ==(final Object other) =>
      identical(this, other) ||
      other is AcceptRangesHeader &&
          const ListEquality<String>().equals(rangeUnits, other.rangeUnits);

  @override
  int get hashCode => const ListEquality<String>().hash(rangeUnits);

  @override
  String toString() {
    return 'AcceptRangesHeader(rangeUnits: $rangeUnits)';
  }
}
