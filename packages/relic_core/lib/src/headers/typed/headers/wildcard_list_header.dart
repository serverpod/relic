import 'dart:typed_data';

import 'package:meta/meta.dart';

import '../../extension/string_list_extensions.dart';
import '../primitives/byte_fields.dart';

/// A generic class representing HTTP headers that accept a list of values with optional wildcards.
///
/// This base class handles the common pattern where a header can either:
/// - Accept a wildcard "*" meaning "accept all"
/// - Accept a list of specific typed values
///
/// The wildcard and list values are mutually exclusive - if wildcard is true,
/// the values list will be empty, and vice versa.
class WildcardListHeader<T> {
  /// The list of values that are accepted
  final List<T> values;

  /// A boolean value indicating whether the header is a wildcard
  bool get isWildcard => values.isEmpty;

  /// Constructs an instance with the given values
  ///
  /// Passing an empty list will raise an ArgumentError
  WildcardListHeader(final List<T> values)
    : values = List.unmodifiable(values) {
    if (values.isEmpty) {
      throw ArgumentError.value(values, 'values', 'Cannot be empty');
    }
  }

  /// Constructs an instance with a wildcard
  const WildcardListHeader.wildcard() : values = const [];

  /// Takes [values] as its own, with no copy.
  ///
  /// For a parser that built the list and hands it over. Not empty.
  @protected
  WildcardListHeader.owned(this.values) : assert(values.isNotEmpty);

  /// Parses header values and returns a WildcardListHeader instance
  factory WildcardListHeader.parse(
    final Iterable<String> headerValues,
    final T Function(String) parseElement,
  ) {
    final splitValues = headerValues.splitTrimAndFilterUnique();

    if (splitValues.isEmpty) {
      throw const FormatException('Value cannot be empty');
    }

    if (splitValues.length == 1 && splitValues.first == '*') {
      return const WildcardListHeader.wildcard();
    }

    if (splitValues.length > 1 && splitValues.contains('*')) {
      throw const FormatException(
        'Wildcard (*) cannot be used with other values',
      );
    }

    final parsedValues = splitValues.map(parseElement).toList(growable: false);
    return WildcardListHeader.owned(parsedValues);
  }

  /// Parses the wire bytes of every field: the comma-separated elements
  /// across [fields], trimmed, dropped when empty and kept once each, as
  /// [parseElement] reads them. One element that is `*` is the wildcard,
  /// and `*` beside a value is an error.
  factory WildcardListHeader.parseFields(
    final List<Uint8List> fields,
    final T Function(Uint8List element) parseElement,
  ) {
    final elements = splitFieldsUnique(fields);
    if (elements.isEmpty) {
      throw const FormatException('Value cannot be empty');
    }
    var wildcards = 0;
    for (final element in elements) {
      if (isWildcardElement(element)) wildcards++;
    }
    if (wildcards > 0) {
      if (elements.length == 1) return const WildcardListHeader.wildcard();
      throw const FormatException(
        'Wildcard (*) cannot be used with other values',
      );
    }
    return WildcardListHeader.owned(
      List.generate(
        elements.length,
        (final i) => parseElement(elements[i]),
        growable: false,
      ),
    );
  }

  /// Converts the header instance into a string representation suitable for HTTP headers
  Iterable<String> encode(final String Function(T) encodeElement) {
    if (isWildcard) {
      return ['*'];
    } else {
      return [values.map(encodeElement).join(', ')];
    }
  }

  @override
  bool operator ==(final Object other) =>
      identical(this, other) ||
      other is WildcardListHeader<T> && _listEquals(values, other.values);

  @override
  int get hashCode => Object.hash(isWildcard, Object.hashAll(values));

  @override
  String toString() =>
      'WildcardListHeader(values: $values, isWildcard: $isWildcard)';

  static bool _listEquals<T>(final List<T> a, final List<T> b) {
    if (a.length != b.length) return false;
    for (int i = 0; i < a.length; i++) {
      if (a[i] != b[i]) return false;
    }
    return true;
  }
}
