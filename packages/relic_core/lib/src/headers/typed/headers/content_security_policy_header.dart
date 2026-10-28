import 'dart:typed_data';

import 'package:collection/collection.dart';

import '../../../../relic_core.dart';
import '../primitives/byte_fields.dart';
import '../primitives/byte_scanner.dart' show latin1Bytes;

/// A class representing the HTTP Content-Security-Policy (CSP) header.
///
/// This class manages CSP directives, providing functionality to parse, add,
/// remove, and generate CSP header values.
final class ContentSecurityPolicyHeader {
  static const codec = HeaderCodec.bytes(_parseBytes, __encode);
  static List<String> __encode(final ContentSecurityPolicyHeader value) => [
    value._encode(),
  ];

  /// A list of CSP directives.
  final List<ContentSecurityPolicyDirective> directives;

  /// Constructs a [ContentSecurityPolicyHeader] instance with the specified
  /// directives.
  ContentSecurityPolicyHeader.directives(
    final List<ContentSecurityPolicyDirective> directives,
  ) : assert(directives.isNotEmpty),
      directives = List.unmodifiable(directives);

  /// Parses a CSP header value and returns a [ContentSecurityPolicyHeader]
  /// instance.
  ///
  /// This method splits the header value by semicolons, trims each directive,
  /// and processes the directive and its values.
  factory ContentSecurityPolicyHeader.parse(final String value) =>
      _parseBytes(latin1Bytes(value));

  /// Takes [directives], a list the parser built, as its own.
  const ContentSecurityPolicyHeader._(this.directives);

  /// [parse] over the wire bytes: `;`-separated directives, each a name
  /// and whitespace-separated values.
  static ContentSecurityPolicyHeader _parseBytes(final Uint8List bytes) {
    final parts = splitUnique(bytes, 0x3B);
    if (parts.isEmpty) {
      throw const FormatException('Value cannot be empty');
    }
    return ContentSecurityPolicyHeader._(
      List.generate(parts.length, (final i) {
        final words = _words(parts[i]);
        return ContentSecurityPolicyDirective(
          name: words.first,
          values: words.sublist(1),
        );
      }, growable: false),
    );
  }

  /// [part] split on runs of whitespace. A trimmed part starts with a
  /// word, so the first element is the name.
  static List<String> _words(final Uint8List part) {
    final words = <String>[];
    var start = 0;
    while (start < part.length) {
      var end = start;
      while (end < part.length && !isTrimByte(part[end])) {
        end++;
      }
      words.add(textOf(part, start, end));
      start = trimStart(part, end, part.length);
    }
    return words;
  }

  /// Converts the [ContentSecurityPolicyHeader] instance into a string
  /// representation suitable for HTTP headers.

  String _encode() {
    return directives.map((final directive) => directive._encode()).join('; ');
  }

  @override
  bool operator ==(final Object other) =>
      identical(this, other) ||
      other is ContentSecurityPolicyHeader &&
          const ListEquality<ContentSecurityPolicyDirective>().equals(
            directives,
            other.directives,
          );

  @override
  int get hashCode =>
      const ListEquality<ContentSecurityPolicyDirective>().hash(directives);

  @override
  String toString() {
    return 'ContentSecurityPolicyHeader(directives: $directives)';
  }
}

/// A class representing a single CSP directive.
class ContentSecurityPolicyDirective {
  /// The name of the directive (e.g., `default-src`, `script-src`).
  final String name;

  /// The values associated with the directive (e.g., `'self'`,
  /// `https://example.com`).
  final Iterable<String> values;

  /// Constructs a [ContentSecurityPolicyDirective] instance with the specified
  /// name and values.
  ///
  /// CSP directive names are ASCII case-insensitive, so the name is
  /// canonicalized to lowercase for case-insensitive equality. The values are
  /// left untouched (source expressions can be case-sensitive).
  ContentSecurityPolicyDirective({
    required final String name,
    required this.values,
  }) : name = name.toLowerCase();

  /// Converts the [ContentSecurityPolicyDirective] instance into a string
  /// representation.
  String _encode() => '$name ${values.join(' ')}';

  @override
  bool operator ==(final Object other) =>
      identical(this, other) ||
      other is ContentSecurityPolicyDirective &&
          name == other.name &&
          const IterableEquality<String>().equals(values, other.values);

  @override
  int get hashCode =>
      Object.hash(name, const IterableEquality<String>().hash(values));

  @override
  String toString() {
    return 'ContentSecurityPolicyDirective(name: $name, values: $values)';
  }
}
