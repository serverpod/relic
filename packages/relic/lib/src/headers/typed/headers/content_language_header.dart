import 'package:collection/collection.dart';

import '../../../../relic.dart';
import '../../extension/string_list_extensions.dart';

/// A class representing the HTTP Content-Language header.
///
/// This class manages the language codes specified in the Content-Language header.
final class ContentLanguageHeader {
  static const codec = HeaderCodec(ContentLanguageHeader.parse, __encode);
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
  factory ContentLanguageHeader.parse(final Iterable<String> values) {
    final splitValues = values.splitTrimAndFilterUnique();
    if (splitValues.isEmpty) {
      throw const FormatException('Value cannot be empty');
    }

    final languages =
        splitValues.map((final language) {
          if (!language.isValidLanguageCode()) {
            throw const FormatException('Invalid language code');
          }
          return language;
        }).toList();

    return ContentLanguageHeader.languages(languages);
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
