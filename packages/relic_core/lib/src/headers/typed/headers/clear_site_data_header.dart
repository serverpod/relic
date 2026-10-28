import 'dart:typed_data';

import '../../../../relic_core.dart';
import '../primitives/byte_fields.dart';
import '../primitives/byte_scanner.dart' show latin1Bytes;
import 'wildcard_list_header.dart';

/// A class representing the HTTP Clear-Site-Data header.
///
/// This header specifies which types of browsing data should be cleared.
final class ClearSiteDataHeader extends WildcardListHeader<ClearSiteDataType> {
  static const codec = HeaderCodec.fields(_parseFields, _encode);

  /// Constructs an instance allowing specific data types to be cleared.
  ClearSiteDataHeader.dataTypes(super.dataTypes);

  /// Constructs an instance allowing all data types to be cleared (`*`).
  const ClearSiteDataHeader.wildcard() : super.wildcard();

  /// Parses the Clear-Site-Data header value and returns a [ClearSiteDataHeader] instance.
  factory ClearSiteDataHeader.parse(final Iterable<String> values) =>
      _parseFields([for (final value in values) latin1Bytes(value)]);

  ClearSiteDataHeader._owned(super.dataTypes) : super.owned();

  /// The list of data types to be cleared
  List<ClearSiteDataType> get dataTypes => values;

  /// The header from the wire bytes of its [fields]: the comma-separated
  /// elements with every `"` dropped, trimmed, non-empty, kept once each.
  static ClearSiteDataHeader _parseFields(final List<Uint8List> fields) {
    final unquoted = <Uint8List>[];
    for (final field in fields) {
      for (final element in splitAll(field)) {
        final kept = Uint8List(element.length);
        var n = 0;
        for (final b in element) {
          if (b != 0x22) kept[n++] = b;
        }
        final value = trimmed(kept, 0, n);
        if (value.isEmpty) continue;
        if (!unquoted.any((final u) => bytesEqual(u, value))) {
          unquoted.add(value);
        }
      }
    }
    if (unquoted.isEmpty) {
      throw const FormatException('Value cannot be empty');
    }
    var wildcards = 0;
    for (final element in unquoted) {
      if (isWildcardElement(element)) wildcards++;
    }
    if (wildcards > 0) {
      if (unquoted.length == 1) return const ClearSiteDataHeader.wildcard();
      throw const FormatException(
        'Wildcard (*) cannot be used with other values',
      );
    }
    return ClearSiteDataHeader._owned(
      List.generate(
        unquoted.length,
        (final i) => ClearSiteDataType._parseBytes(unquoted[i]),
        growable: false,
      ),
    );
  }

  static List<String> encodeHeader(final ClearSiteDataHeader header) {
    if (header.isWildcard) {
      return ['"*"'];
    } else {
      return [
        header.dataTypes
            .map((final dataType) => '"${dataType.value}"')
            .join(', '),
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

  /// Predefined Clear-Site-Data types per the [W3C spec][csd]:
  /// `cache`, `cookies`, `storage`, `executionContexts`.
  ///
  /// [csd]: https://www.w3.org/TR/clear-site-data/#grammardef-type
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
  factory ClearSiteDataType.parse(final String value) =>
      ClearSiteDataType._parseBytes(trimmed(latin1Bytes(value)));

  /// [parse] over the wire bytes of one trimmed element.
  static ClearSiteDataType _parseBytes(final Uint8List element) {
    if (element.isEmpty) {
      throw const FormatException('Value cannot be empty');
    }
    switch (textOf(element)) {
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
