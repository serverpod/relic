import '../../../../relic.dart';

/// A class representing the HTTP Expect header.
///
/// This class manages the directive for the Expect header, such as `100-continue`.
/// It provides functionality to parse and generate Expect header values.
final class ExpectHeader {
  static const codec = HeaderCodec.single(ExpectHeader.parse, __encode);
  static List<String> __encode(final ExpectHeader value) => [value._encode()];

  /// The string representation of the expectation directive.
  final String value;

  /// Constructs an [ExpectHeader] instance with the specified value.
  const ExpectHeader._(this.value);

  /// Predefined expectation directives.
  static const _continue100 = '100-continue';

  static const continue100 = ExpectHeader._(_continue100);

  /// Parses a [value] and returns the corresponding [ExpectHeader] instance.
  /// If the value does not match any predefined types, it returns a custom instance.
  factory ExpectHeader.parse(final String value) {
    final trimmed = value.trim();
    if (trimmed.isEmpty) {
      throw const FormatException('Value cannot be empty');
    }
    switch (trimmed) {
      case _continue100:
        return continue100;
      default:
        throw const FormatException('Invalid value');
    }
  }

  /// Converts the [ExpectHeader] instance into a string representation
  /// suitable for HTTP headers.

  String _encode() => value;

  @override
  bool operator ==(final Object other) =>
      identical(this, other) || other is ExpectHeader && value == other.value;

  @override
  int get hashCode => value.hashCode;

  @override
  String toString() {
    return 'ExpectHeader(value: $value)';
  }
}
