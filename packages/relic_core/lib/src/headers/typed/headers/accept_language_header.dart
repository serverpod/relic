import 'dart:typed_data';

import '../../../../relic_core.dart';
import '../primitives/byte_fields.dart';
import '../primitives/byte_scanner.dart' show latin1Bytes;
import 'util/qvalue.dart';
import 'wildcard_list_header.dart';

/// A class representing the HTTP Accept-Language header.
///
/// This header specifies the natural languages that are preferred in the response.
final class AcceptLanguageHeader extends WildcardListHeader<LanguageQuality> {
  static const codec = HeaderCodec.fields(_parseFields, _encode);

  /// Constructs an instance with the given languages
  AcceptLanguageHeader.languages(super.languages);

  /// Constructs an instance with a wildcard language
  const AcceptLanguageHeader.wildcard() : super.wildcard();

  AcceptLanguageHeader._owned(super.languages) : super.owned();

  /// Parses the Accept-Language header [values] and returns an
  /// [AcceptLanguageHeader] instance.
  factory AcceptLanguageHeader.parse(final Iterable<String> values) =>
      _parseFields([for (final value in values) latin1Bytes(value)]);

  /// The list of languages that are accepted
  List<LanguageQuality> get languages => values;

  /// The header from the wire bytes of its [fields].
  static AcceptLanguageHeader _parseFields(final List<Uint8List> fields) {
    final parsed = WildcardListHeader.parseFields(
      fields,
      LanguageQuality._parseBytes,
    );
    if (parsed.isWildcard) return const AcceptLanguageHeader.wildcard();
    return AcceptLanguageHeader._owned(parsed.values);
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
  factory LanguageQuality.parse(final String value) =>
      LanguageQuality._parseBytes(latin1Bytes(value));

  /// [parse] over the wire bytes of one element.
  static LanguageQuality _parseBytes(final Uint8List element) {
    var semi = indexOfByte(element, 0x3B);
    if (semi < 0) semi = element.length;
    final language = lowerTextOf(element, 0, trimEnd(element, 0, semi));
    if (language.isEmpty) {
      throw const FormatException('Invalid language');
    }
    return LanguageQuality(language, qualityParameter(element, semi + 1));
  }

  /// Encodes this [LanguageQuality] into a string representation suitable for
  /// HTTP headers. The q-value is rendered with at most 3 fractional digits
  /// per RFC 9110 12.4.2.
  String encode() {
    return quality == 1.0 ? language : '$language;q=${formatQValue(quality!)}';
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
