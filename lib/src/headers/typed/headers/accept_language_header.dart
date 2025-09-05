import 'package:collection/collection.dart';

import '../../../../relic.dart';
import '../../extension/string_list_extensions.dart';

/// A class representing the HTTP Accept-Language header.
///
/// This header specifies the natural languages that are preferred in the response.
final class AcceptLanguageHeader {
  static const codec = HeaderCodec(AcceptLanguageHeader.parse, __encode);
  static List<String> __encode(final AcceptLanguageHeader value) =>
      [value._encode()];

  /// The list of languages that are accepted.
  final List<LanguageQuality> languages;

  /// A boolean value indicating whether the Accept-Language header is a wildcard.
  final bool isWildcard;

  /// Constructs an instance of [AcceptLanguageHeader] with the given languages.
  AcceptLanguageHeader.languages(
      {required final List<LanguageQuality> languages})
      : assert(languages.isNotEmpty),
        languages = List.unmodifiable(languages),
        isWildcard = false;

  /// Constructs an instance of [AcceptLanguageHeader] with a wildcard language.
  const AcceptLanguageHeader.wildcard()
      : languages = const [],
        isWildcard = true;

  /// Parses the Accept-Language header value and returns an [AcceptLanguageHeader] instance.
  factory AcceptLanguageHeader.parse(final Iterable<String> values) {
    final splitValues = values.splitTrimAndFilterUnique();

    if (splitValues.isEmpty) {
      throw const FormatException('Value cannot be empty');
    }

    if (splitValues.length == 1 && splitValues.first == '*') {
      return const AcceptLanguageHeader.wildcard();
    }

    if (splitValues.length > 1 && splitValues.contains('*')) {
      throw const FormatException(
          'Wildcard (*) cannot be used with other values');
    }

    final languages = splitValues.map((final value) {
      final languageParts = value.split(';q=');
      final language = languageParts[0].trim().toLowerCase();
      if (language.isEmpty) {
        throw const FormatException('Invalid language');
      }
      double? quality;
      if (languageParts.length > 1) {
        final value = double.tryParse(languageParts[1].trim());
        if (value == null || value < 0 || value > 1) {
          throw const FormatException('Invalid quality value');
        }
        quality = value;
      }
      return LanguageQuality(language, quality);
    }).toList();

    return AcceptLanguageHeader.languages(languages: languages);
  }

  /// Converts the [AcceptLanguageHeader] instance into a string representation suitable for HTTP headers.
  String _encode() =>
      isWildcard ? '*' : languages.map((final e) => e._encode()).join(', ');

  @override
  bool operator ==(final Object other) =>
      identical(this, other) ||
      other is AcceptLanguageHeader &&
          isWildcard == other.isWildcard &&
          const ListEquality<LanguageQuality>()
              .equals(languages, other.languages);

  @override
  int get hashCode => Object.hash(
      isWildcard, const ListEquality<LanguageQuality>().hash(languages));

  @override
  String toString() => 'AcceptLanguageHeader(languages: $languages)';
}

/// A class representing a language with an optional quality value.
class LanguageQuality {
  /// The language value.
  final String language;

  /// The quality value (default is 1.0).
  final double? quality;

  /// Constructs an instance of [LanguageQuality].
  const LanguageQuality(this.language, [final double? quality])
      : quality = quality ?? 1.0;

  /// Converts the [LanguageQuality] instance into a string representation suitable for HTTP headers.
  String _encode() => quality == 1.0 ? language : '$language;q=$quality';

  @override
  bool operator ==(final Object other) =>
      identical(this, other) ||
      other is LanguageQuality &&
          language == other.language &&
          quality == other.quality;

  @override
  int get hashCode => Object.hash(language, quality);

  @override
  String toString() =>
      'LanguageQuality(language: $language, quality: $quality)';
}
