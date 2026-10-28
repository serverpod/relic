import 'dart:typed_data';

import 'package:collection/collection.dart';

import '../../../../relic_core.dart';
import '../primitives/byte_fields.dart';
import '../primitives/byte_scanner.dart' show latin1Bytes;

/// A class representing the HTTP Content-Language header.
///
/// This class manages the language codes specified in the Content-Language header.
final class ContentLanguageHeader {
  static const codec = HeaderCodec.fields(_parseFields, __encode);
  static List<String> __encode(final ContentLanguageHeader value) => [
    value._encode(),
  ];

  /// The list of language codes specified in the header.
  final List<String> languages;

  /// Constructs a [ContentLanguageHeader] instance with the specified language codes.
  ContentLanguageHeader.languages(final Iterable<String> languages)
    : assert(languages.isNotEmpty),
      languages = List.unmodifiable(languages);

  /// Parses the Content-Language header value and returns a [ContentLanguageHeader] instance.
  ///
  /// This method splits the header value by commas and trims each language code.
  factory ContentLanguageHeader.parse(final Iterable<String> values) =>
      _parseFields([for (final value in values) latin1Bytes(value)]);

  /// Takes [languages], a list the parser built, as its own.
  const ContentLanguageHeader._(this.languages);

  /// The header from the wire bytes of its [fields].
  ///
  /// Each tag is checked against the full BCP 47 grammar (RFC 5646), so
  /// `es-419`, `zh-Hant-TW` and `x-foo` pass, and kept in canonical case
  /// so equality and hashing ignore case (`en-US` == `EN-us`).
  static ContentLanguageHeader _parseFields(final List<Uint8List> fields) {
    final elements = splitFieldsUnique(fields);
    if (elements.isEmpty) {
      throw const FormatException('Value cannot be empty');
    }
    return ContentLanguageHeader._(
      List.generate(elements.length, (final i) {
        try {
          return LanguageTag.parse(textOf(elements[i])).encode();
        } on FormatException {
          throw const FormatException('Invalid language code');
        }
      }, growable: false),
    );
  }

  /// Converts the [ContentLanguageHeader] instance into a string representation
  /// suitable for HTTP headers.

  String _encode() => languages.join(', ');

  @override
  bool operator ==(final Object other) =>
      identical(this, other) ||
      other is ContentLanguageHeader &&
          const ListEquality<String>().equals(languages, other.languages);

  @override
  int get hashCode => const ListEquality<String>().hash(languages);

  @override
  String toString() {
    return 'ContentLanguageHeader(languages: $languages)';
  }
}
