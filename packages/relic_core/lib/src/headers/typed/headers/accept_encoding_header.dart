import '../../../../relic_core.dart';
import 'wildcard_list_header.dart';

/// A class representing the HTTP Accept-Encoding header.
///
/// This header specifies the content encoding that the client can understand.
final class AcceptEncodingHeader extends WildcardListHeader<EncodingQuality> {
  static const codec = HeaderCodec(_parse, _encode);

  /// Constructs an instance with the given encodings
  AcceptEncodingHeader.encodings(super.encodings);

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
      return AcceptEncodingHeader.encodings(parsed.values);
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
  ///
  /// The weight is recognized as the parameter named `q` (RFC 9110 12.4.2),
  /// case-insensitive, tolerating OWS around the surrounding `;` and `=`.
  factory EncodingQuality.parse(final String value) {
    final parts = value.split(';');
    final encoding = parts[0].trim().toLowerCase();
    if (encoding.isEmpty) {
      throw const FormatException('Invalid encoding');
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

    return EncodingQuality(encoding, quality);
  }

  /// Encodes this [EncodingQuality] into a string representation suitable for
  /// HTTP headers. The q-value is rendered with at most 3 fractional digits
  /// per RFC 9110 12.4.2.
  String encode() {
    return quality == 1.0 ? encoding : '$encoding;q=${_formatQValue(quality!)}';
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
      other is EncodingQuality &&
          encoding == other.encoding &&
          quality == other.quality;

  @override
  int get hashCode => Object.hash(encoding, quality);

  @override
  String toString() =>
      'EncodingQuality(encoding: $encoding, quality: $quality)';
}
