import '../../../../relic.dart';
import 'wildcard_list_header.dart';

/// A class representing the HTTP Accept-Language header.
///
/// This header specifies the natural languages that are preferred in the response.
final class AcceptLanguageHeader extends WildcardListHeader<LanguageQuality> {
  static const codec = HeaderCodec(_parse, _encode);

  /// Constructs an instance with the given languages
  AcceptLanguageHeader.languages(
      {required final List<LanguageQuality> languages})
      : super(languages);

  /// Constructs an instance with a wildcard language
  const AcceptLanguageHeader.wildcard() : super.wildcard();

  /// Parses the Accept-Language header value and returns an [AcceptLanguageHeader] instance
  factory AcceptLanguageHeader.parse(final Iterable<String> values) {
    return _parse(values);
  }

  /// The list of languages that are accepted
  List<LanguageQuality> get languages => values;

  static AcceptLanguageHeader _parse(final Iterable<String> values) {
    final parsed = WildcardListHeader.parse(values, LanguageQuality.parse);

    if (parsed.isWildcard) {
      return const AcceptLanguageHeader.wildcard();
    } else {
      return AcceptLanguageHeader.languages(languages: parsed.values);
    }
  }

  static List<String> encodeHeader(final AcceptLanguageHeader header) {
    return header.encode((final LanguageQuality lq) => lq.encode()).toList();
  }

  static List<String> _encode(final AcceptLanguageHeader header) {
    return encodeHeader(header);
  }
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

  /// Parses a string value and returns a [LanguageQuality] instance.
  factory LanguageQuality.parse(final String value) {
    final languageParts = value.split(';q=');
    final language = languageParts[0].trim().toLowerCase();
    if (language.isEmpty) {
      throw const FormatException('Invalid language');
    }

    double? quality;
    if (languageParts.length > 1) {
      final qualityValue = double.tryParse(languageParts[1].trim());
      if (qualityValue == null || qualityValue < 0 || qualityValue > 1) {
        throw const FormatException('Invalid quality value');
      }
      quality = qualityValue;
    }

    return LanguageQuality(language, quality);
  }

  /// Encodes this [LanguageQuality] into a string representation suitable for HTTP headers.
  String encode() {
    return quality == 1.0 ? language : '$language;q=$quality';
  }

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
