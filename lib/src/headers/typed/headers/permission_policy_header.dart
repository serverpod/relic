import '../../../../relic.dart';
import '../../extension/string_list_extensions.dart';

/// A class representing the HTTP Permissions-Policy header.
///
/// This class manages Permissions-Policy directives, providing functionality to parse,
/// add, remove, and generate Permissions-Policy header values.
final class PermissionsPolicyHeader {
  static const codec =
      HeaderCodec.single(PermissionsPolicyHeader.parse, __encode);
  static List<String> __encode(final PermissionsPolicyHeader value) =>
      [value._encode()];

  /// A list of Permissions-Policy directives.
  final List<PermissionsPolicyDirective> directives;

  /// Constructs a [PermissionsPolicyHeader] instance with the specified directives.
  const PermissionsPolicyHeader({required this.directives});

  /// Parses the Permissions-Policy header value and returns a [PermissionsPolicyHeader] instance.
  ///
  /// This method splits the header value by commas, trims each directive,
  /// and processes the directive and its values.
  factory PermissionsPolicyHeader.parse(final String value) {
    final splitValues = value.splitTrimAndFilterUnique(separator: ',');
    if (splitValues.isEmpty) {
      throw const FormatException('Value cannot be empty');
    }

    final directives = <PermissionsPolicyDirective>[];
    for (final part in splitValues) {
      final directiveParts = part.split('=');
      final name = directiveParts.first.trim();
      final values = directiveParts.length > 1
          ? directiveParts[1]
              .replaceAll('(', '')
              .replaceAll(')', '')
              .split(' ')
              .map((final s) => s.trim())
              .toList()
          : <String>[];

      directives.add(
        PermissionsPolicyDirective(
          name: name,
          values: values,
        ),
      );
    }

    return PermissionsPolicyHeader(directives: directives);
  }

  /// Converts the [PermissionsPolicyHeader] instance into a string
  /// representation suitable for HTTP headers.

  String _encode() {
    return directives.map((final directive) => directive._encode()).join(', ');
  }

  @override
  String toString() {
    return 'PermissionsPolicyHeader(directives: $directives)';
  }
}

/// A class representing a single Permissions-Policy directive.
class PermissionsPolicyDirective {
  /// The name of the directive (e.g., `geolocation`, `microphone`).
  final String name;

  /// The values associated with the directive (e.g., `self`, `https://example.com`).
  final Iterable<String> values;

  /// Constructs a [PermissionsPolicyDirective] instance with the specified name and values.
  const PermissionsPolicyDirective({
    required this.name,
    required this.values,
  });

  /// Converts the [PermissionsPolicyDirective] instance into a string representation.
  String _encode() {
    final valuesStr = values.isNotEmpty ? '(${values.join(' ')})' : '()';
    return '$name=$valuesStr';
  }

  @override
  String toString() {
    return 'PermissionsPolicyDirective(name: $name, values: $values)';
  }
}
