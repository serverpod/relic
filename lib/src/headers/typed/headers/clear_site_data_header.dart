import '../../../../relic.dart';
import 'wildcard_list_header.dart';

/// A class representing the HTTP Clear-Site-Data header.
///
/// This header specifies which types of browsing data should be cleared.
final class ClearSiteDataHeader extends WildcardListHeader<ClearSiteDataType> {
  static const codec = HeaderCodec(_parse, _encode);

  /// Constructs an instance allowing specific data types to be cleared.
  ClearSiteDataHeader.dataTypes(
      {required final List<ClearSiteDataType> dataTypes})
      : super(dataTypes);

  /// Constructs an instance allowing all data types to be cleared (`*`).
  const ClearSiteDataHeader.wildcard() : super.wildcard();

  /// Parses the Clear-Site-Data header value and returns a [ClearSiteDataHeader] instance.
  factory ClearSiteDataHeader.parse(final Iterable<String> values) {
    return _parse(values);
  }

  /// The list of data types to be cleared
  List<ClearSiteDataType> get dataTypes => values;

  static ClearSiteDataHeader _parse(final Iterable<String> values) {
    // Custom parsing logic for ClearSiteData with quote removal
    final splitValues = values
        .expand((final value) => value.split(','))
        .map((final s) => s.trim().replaceAll('"', ''))
        .where((final s) => s.isNotEmpty)
        .toSet()
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

  static List<String> encodeHeader(final ClearSiteDataHeader header) {
    if (header.isWildcard) {
      return ['*'];
    } else {
      return [
        header.dataTypes
            .map((final dataType) => '"${dataType.value}"')
            .join(', ')
      ];
    }
  }

  static List<String> _encode(final ClearSiteDataHeader header) {
    return encodeHeader(header);
  }
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
