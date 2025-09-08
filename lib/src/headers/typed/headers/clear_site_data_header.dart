import 'package:collection/collection.dart';

import '../../../../relic.dart';
import '../../extension/string_list_extensions.dart';

/// A class representing the HTTP Clear-Site-Data header.
///
/// This header specifies which types of browsing data should be cleared.
final class ClearSiteDataHeader {
  static const codec = HeaderCodec(ClearSiteDataHeader.parse, __encode);
  static List<String> __encode(final ClearSiteDataHeader value) =>
      [value._encode()];

  /// The list of data types to be cleared.
  final List<ClearSiteDataType> dataTypes;

  /// Whether all data types are allowed to be cleared (`*`).
  final bool isWildcard;

  /// Constructs an instance allowing specific data types to be cleared.
  ClearSiteDataHeader.dataTypes(
      {required final List<ClearSiteDataType> dataTypes})
      : assert(dataTypes.isNotEmpty),
        dataTypes = List.unmodifiable(dataTypes),
        isWildcard = false;

  /// Constructs an instance allowing all data types to be cleared (`*`).
  const ClearSiteDataHeader.wildcard()
      : dataTypes = const [],
        isWildcard = true;

  /// Parses the Clear-Site-Data header value and returns a [ClearSiteDataHeader] instance.
  ///
  /// This method splits the header value by commas, trims each data type,
  /// and processes the data type values.
  factory ClearSiteDataHeader.parse(final Iterable<String> values) {
    final splitValues = values
        .splitTrimAndFilterUnique()
        .map((final s) => s.replaceAll('"', ''))
        .where((final s) => s.isNotEmpty)
        .toList();

    if (splitValues.isEmpty) {
      throw const FormatException('Value cannot be empty');
    }

    if (splitValues.length == 1 && splitValues.first == '*') {
      return const ClearSiteDataHeader.wildcard();
    }

    if (splitValues.length > 1 && splitValues.contains('*')) {
      throw const FormatException(
          'Wildcard (*) cannot be used with other values');
    }

    final dataTypes = splitValues.map(ClearSiteDataType.parse).toList();

    return ClearSiteDataHeader.dataTypes(dataTypes: dataTypes);
  }

  /// Converts the [ClearSiteDataHeader] instance into a string representation suitable for HTTP headers.
  ///
  /// This method generates the header string by concatenating the data types.
  String _encode() {
    return isWildcard
        ? '*'
        : dataTypes.map((final dataType) => '"${dataType.value}"').join(', ');
  }

  @override
  bool operator ==(final Object other) =>
      identical(this, other) ||
      other is ClearSiteDataHeader &&
          isWildcard == other.isWildcard &&
          const ListEquality<ClearSiteDataType>()
              .equals(dataTypes, other.dataTypes);

  @override
  int get hashCode => Object.hash(
      isWildcard, const ListEquality<ClearSiteDataType>().hash(dataTypes));

  @override
  String toString() =>
      'ClearSiteDataHeader(dataTypes: $dataTypes, isWildcard: $isWildcard)';
}

/// A class representing a single Clear-Site-Data type.
class ClearSiteDataType {
  /// The string representation of the Clear-Site-Data type.
  final String value;

  /// Private constructor for [ClearSiteDataType].P
  const ClearSiteDataType._(this.value);

  /// Predefined Clear-Site-Data types.
  static const _cache = 'cache';
  static const _cookies = 'cookies';
  static const _storage = 'storage';
  static const _executionContexts = 'executionContexts';

  static const cache = ClearSiteDataType._(_cache);
  static const cookies = ClearSiteDataType._(_cookies);
  static const storage = ClearSiteDataType._(_storage);
  static const executionContexts = ClearSiteDataType._(_executionContexts);

  /// Parses a [value] and returns the corresponding [ClearSiteDataType] instance.
  /// If the value does not match any predefined types, it returns a custom instance.
  factory ClearSiteDataType.parse(final String value) {
    final trimmed = value.trim();
    if (trimmed.isEmpty) {
      throw const FormatException('Value cannot be empty');
    }
    switch (trimmed) {
      case _cache:
        return cache;
      case _cookies:
        return cookies;
      case _storage:
        return storage;
      case _executionContexts:
        return executionContexts;
      default:
        throw const FormatException('Invalid value');
    }
  }

  @override
  bool operator ==(final Object other) =>
      identical(this, other) ||
      other is ClearSiteDataType && value == other.value;

  @override
  int get hashCode => value.hashCode;

  @override
  String toString() => 'ClearSiteDataType(value: $value)';
}
