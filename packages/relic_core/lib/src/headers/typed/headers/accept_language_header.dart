import '../../../../relic_core.dart';
import 'wildcard_list_header.dart';

/// A class representing the HTTP Accept-Language header.
///
/// This header specifies the natural languages that are preferred in the response.
final class AcceptLanguageHeader extends WildcardListHeader<LanguageQuality> {
  static const codec = HeaderCodec(_parse, _encode);

  /// Constructs an instance with the given languages
  AcceptLanguageHeader.languages(super.languages);

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
      return AcceptLanguageHeader.languages(parsed.values);
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
  ///
  /// The weight is recognized as the parameter named `q` (RFC 9110 12.4.2),
  /// case-insensitive, tolerating OWS around the surrounding `;` and `=`.
  factory LanguageQuality.parse(final String value) {
    final parts = value.split(';');
    final language = parts[0].trim().toLowerCase();
    if (language.isEmpty) {
      throw const FormatException('Invalid language');
    }

    double? quality;
    for (var i = 1; i < parts.length; i++) {
      final eq = parts[i].indexOf('=');
      if (eq < 0) continue;
      final name = parts[i].substring(0, eq).trim();
      if (name.toLowerCase() != 'q') continue;
      final parsed = double.tryParse(parts[i].substring(eq + 1).trim());
      if (parsed == null || parsed < 0 || parsed > 1) {
        throw const FormatException('Invalid quality value');
      }
      quality = parsed;
      break;
    }

    return LanguageQuality(language, quality);
  }

  /// Encodes this [LanguageQuality] into a string representation suitable for
  /// HTTP headers. The q-value is rendered with at most 3 fractional digits
  /// per RFC 9110 12.4.2.
  String encode() {
    return quality == 1.0 ? language : '$language;q=${_formatQValue(quality!)}';
  }

  static String _formatQValue(final double q) {
    var s = q.toStringAsFixed(3);
    while (s.endsWith('0') && !s.endsWith('.0')) {
      s = s.substring(0, s.length - 1);
    }
    if (s.endsWith('.0')) s = s.substring(0, s.length - 2);
    return s;
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
