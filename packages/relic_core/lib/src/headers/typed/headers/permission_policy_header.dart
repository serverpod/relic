import 'package:collection/collection.dart';

import '../../../../relic_core.dart';
import '../../extension/string_list_extensions.dart';

/// A class representing the HTTP Permissions-Policy header.
///
/// This class manages Permissions-Policy directives, providing functionality to parse,
/// add, remove, and generate Permissions-Policy header values.
final class PermissionsPolicyHeader {
  static const codec = HeaderCodec.single(
    PermissionsPolicyHeader.parse,
    __encode,
  );
  static List<String> __encode(final PermissionsPolicyHeader value) => [
    value._encode(),
  ];

  /// A list of Permissions-Policy directives.
  final List<PermissionsPolicyDirective> directives;

  /// Constructs a [PermissionsPolicyHeader] instance with the specified directives.
  PermissionsPolicyHeader.directives(
    final List<PermissionsPolicyDirective> directives,
  ) : assert(directives.isNotEmpty),
      directives = List.unmodifiable(directives);

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
                .where((final s) => s.isNotEmpty)
                .map(_unquote)
                .toList()
          : <String>[];

      directives.add(PermissionsPolicyDirective(name: name, values: values));
    }

    return PermissionsPolicyHeader.directives(directives);
  }

  /// Converts the [PermissionsPolicyHeader] instance into a string
  /// representation suitable for HTTP headers.

  String _encode() {
    return directives.map((final directive) => directive._encode()).join(', ');
  }

  @override
  bool operator ==(final Object other) =>
      identical(this, other) ||
      other is PermissionsPolicyHeader &&
          const ListEquality<PermissionsPolicyDirective>().equals(
            directives,
            other.directives,
          );

  @override
  int get hashCode =>
      const ListEquality<PermissionsPolicyDirective>().hash(directives);

  @override
  String toString() {
    return 'PermissionsPolicyHeader(directives: $directives)';
  }
}

String _unquote(final String s) {
  if (s.length >= 2 && s.startsWith('"') && s.endsWith('"')) {
    return s
        .substring(1, s.length - 1)
        .replaceAll(r'\"', '"')
        .replaceAll(r'\\', r'\');
  }
  return s;
}

/// A class representing a single Permissions-Policy directive.
class PermissionsPolicyDirective {
  /// The name of the directive (e.g., `geolocation`, `microphone`).
  final String name;

  /// The values associated with the directive (e.g., `self`, `https://example.com`).
  final Iterable<String> values;

  /// Constructs a [PermissionsPolicyDirective] instance with the specified name and values.
  const PermissionsPolicyDirective({required this.name, required this.values});

  /// Converts the [PermissionsPolicyDirective] instance into a string
  /// representation.
  ///
  /// Per the W3C Permissions Policy spec, the header is an RFC 8941
  /// Structured Field Dictionary whose values are inner-lists of sf-tokens
  /// and sf-strings. The tokens `*` and `self` appear bare; URL origins MUST
  /// be serialized as sf-strings (RFC 8941 String), i.e. quoted with
  /// `"..."`. Without this distinction, conforming user agents drop the
  /// entire directive because `https://example.com` is not a valid sf-token.
  String _encode() {
    final rendered = values.map(_renderItem).toList();
    final valuesStr = rendered.isNotEmpty ? '(${rendered.join(' ')})' : '()';
    return '$name=$valuesStr';
  }

  static String _renderItem(final String v) {
    if (v == '*' || v == 'self') return v;
    return '"${v.replaceAll(r'\', r'\\').replaceAll('"', r'\"')}"';
  }

  @override
  bool operator ==(final Object other) =>
      identical(this, other) ||
      other is PermissionsPolicyDirective &&
          name == other.name &&
          const IterableEquality<String>().equals(values, other.values);

  @override
  int get hashCode =>
      Object.hash(name, const IterableEquality<String>().hash(values));

  @override
  String toString() {
    return 'PermissionsPolicyDirective(name: $name, values: $values)';
  }
}
