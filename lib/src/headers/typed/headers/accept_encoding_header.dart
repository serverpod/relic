import '../../../../relic.dart';
import 'wildcard_list_header.dart';

/// A class representing the HTTP Accept-Encoding header.
///
/// This header specifies the content encoding that the client can understand.
final class AcceptEncodingHeader extends WildcardListHeader<EncodingQuality> {
  static const codec = HeaderCodec(_parse, _encode);

  /// Constructs an instance with the given encodings
  AcceptEncodingHeader.encodings(
      {required final List<EncodingQuality> encodings})
      : super(encodings);

  /// Constructs an instance with a wildcard encoding
  const AcceptEncodingHeader.wildcard() : super.wildcard();

  /// Parses the Accept-Encoding header value and returns an [AcceptEncodingHeader] instance
  factory AcceptEncodingHeader.parse(final Iterable<String> values) {
    return _parse(values);
  }

  /// The list of encodings that are accepted
  List<EncodingQuality> get encodings => values;

  static AcceptEncodingHeader _parse(final Iterable<String> values) {
    final parsed = WildcardListHeader.parse(values, EncodingQuality.parse);

    if (parsed.isWildcard) {
      return const AcceptEncodingHeader.wildcard();
    } else {
      return AcceptEncodingHeader.encodings(encodings: parsed.values);
    }
  }

  static List<String> encodeHeader(final AcceptEncodingHeader header) {
    return header.encode((final EncodingQuality eq) => eq.encode()).toList();
  }

  static List<String> _encode(final AcceptEncodingHeader header) {
    return encodeHeader(header);
  }
}

/// A class representing an encoding with an optional quality value.
class EncodingQuality {
  /// The encoding value.
  final String encoding;

  /// The quality value (default is 1.0).
  final double? quality;

  /// Constructs an instance of [EncodingQuality].
  EncodingQuality(this.encoding, [final double? quality])
      : quality = quality ?? 1.0;

  /// Parses a string value and returns an [EncodingQuality] instance.
  factory EncodingQuality.parse(final String value) {
    final encodingParts = value.split(';q=');
    final encoding = encodingParts[0].trim().toLowerCase();
    if (encoding.isEmpty) {
      throw const FormatException('Invalid encoding');
    }

    double? quality;
    if (encodingParts.length > 1) {
      final qualityValue = double.tryParse(encodingParts[1].trim());
      if (qualityValue == null || qualityValue < 0 || qualityValue > 1) {
        throw const FormatException('Invalid quality value');
      }
      quality = qualityValue;
    }

    return EncodingQuality(encoding, quality);
  }

  /// Encodes this [EncodingQuality] into a string representation suitable for HTTP headers.
  String encode() {
    return quality == 1.0 ? encoding : '$encoding;q=$quality';
  }

  @override
  bool operator ==(final Object other) =>
      identical(this, other) ||
      other is EncodingQuality &&
          encoding == other.encoding &&
          quality == other.quality;

  @override
  int get hashCode => Object.hash(encoding, quality);

  @override
  String toString() =>
      'EncodingQuality(encoding: $encoding, quality: $quality)';
}
