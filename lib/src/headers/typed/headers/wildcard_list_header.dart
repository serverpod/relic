import '../../extension/string_list_extensions.dart';

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
  final bool isWildcard;

  /// Constructs an instance with the given values
  WildcardListHeader(final List<T> values)
      : assert(values.isNotEmpty, 'Values list cannot be empty'),
        values = List.unmodifiable(values),
        isWildcard = false;

  /// Constructs an instance with a wildcard
  const WildcardListHeader.wildcard()
      : values = const [],
        isWildcard = true;

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
          'Wildcard (*) cannot be used with other values');
    }

    final parsedValues = splitValues.map(parseElement).toList();
    return WildcardListHeader(parsedValues);
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
      other is WildcardListHeader<T> &&
          isWildcard == other.isWildcard &&
          _listEquals(values, other.values);

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
