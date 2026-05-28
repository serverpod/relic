import 'package:collection/collection.dart';

import '../../../../relic_core.dart';

const int _comma = 0x2C;
const int _space = 0x20;

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
    if (value.trim().isEmpty) {
      throw const FormatException('Value cannot be empty');
    }

    final directives = <PermissionsPolicyDirective>[];
    // Split directives at top-level commas only, so a comma inside an
    // sf-string value does not split a directive (RFC 8941 dictionary).
    for (final part in HeaderScanner(value).splitTopLevel(_comma)) {
      if (part.isEmpty) continue;
      // The first '=' separates the feature name from its inner-list value;
      // an sf-string in the value may itself contain '=' (e.g. a URL query).
      final eq = part.indexOf('=');
      final name = (eq < 0 ? part : part.substring(0, eq)).trim();
      final rawList = eq < 0 ? '' : part.substring(eq + 1).trim();
      directives.add(
        PermissionsPolicyDirective(
          name: name,
          values: _parseInnerList(rawList),
        ),
      );
    }

    if (directives.isEmpty) {
      throw const FormatException('Value cannot be empty');
    }

    return PermissionsPolicyHeader.directives(directives);
  }

  /// Parses an inner-list value `(item item ...)` (or a bare single item)
  /// into its component sf-tokens / sf-strings, splitting on top-level
  /// whitespace so an sf-string containing a space stays intact.
  static List<String> _parseInnerList(final String raw) {
    var inner = raw;
    if (inner.startsWith('(') && inner.endsWith(')')) {
      inner = inner.substring(1, inner.length - 1);
    }
    inner = inner.trim();
    if (inner.isEmpty) return const [];
    return HeaderScanner(inner)
        .splitTopLevel(_space)
        .where((final s) => s.isNotEmpty)
        .map(_unquote)
        .toList();
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
    for (var i = 0; i < v.length; i++) {
      final c = v.codeUnitAt(i);
      // Reject CTLs so a value built from untrusted input cannot inject a
      // CR/LF (or other control byte) into the serialized header.
      if (c <= 0x1F || c == 0x7F) {
        throw const FormatException(
          'Permissions-Policy value must not contain control characters',
        );
      }
    }
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
