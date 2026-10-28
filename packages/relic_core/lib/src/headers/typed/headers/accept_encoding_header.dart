import 'dart:typed_data';

import '../../../../relic_core.dart';
import '../primitives/byte_fields.dart';
import '../primitives/byte_scanner.dart' show latin1Bytes;
import 'util/qvalue.dart';
import 'wildcard_list_header.dart';

/// A class representing the HTTP Accept-Encoding header.
///
/// This header specifies the content encoding that the client can understand.
final class AcceptEncodingHeader extends WildcardListHeader<EncodingQuality> {
  static const codec = HeaderCodec.fields(_parseFields, _encode);

  /// Constructs an instance with the given encodings
  AcceptEncodingHeader.encodings(super.encodings);

  /// Constructs an instance with a wildcard encoding
  const AcceptEncodingHeader.wildcard() : super.wildcard();

  /// Parses the Accept-Encoding header [values] and returns an
  /// [AcceptEncodingHeader] instance.
  factory AcceptEncodingHeader.parse(final Iterable<String> values) =>
      _parseFields([for (final value in values) latin1Bytes(value)]);

  AcceptEncodingHeader._owned(super.encodings) : super.owned();

  /// The list of encodings that are accepted
  List<EncodingQuality> get encodings => values;

  /// The header from the wire bytes of its [fields].
  static AcceptEncodingHeader _parseFields(final List<Uint8List> fields) {
    final parsed = WildcardListHeader.parseFields(
      fields,
      EncodingQuality._parseBytes,
    );
    if (parsed.isWildcard) return const AcceptEncodingHeader.wildcard();
    return AcceptEncodingHeader._owned(parsed.values);
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
  factory EncodingQuality.parse(final String value) =>
      EncodingQuality._parseBytes(latin1Bytes(value));

  /// [parse] over the wire bytes of one element.
  static EncodingQuality _parseBytes(final Uint8List element) {
    var semi = indexOfByte(element, 0x3B);
    if (semi < 0) semi = element.length;
    final encoding = lowerTextOf(element, 0, trimEnd(element, 0, semi));
    if (encoding.isEmpty) {
      throw const FormatException('Invalid encoding');
    }
    return EncodingQuality(encoding, qualityParameter(element, semi + 1));
  }

  /// Encodes this [EncodingQuality] into a string representation suitable for
  /// HTTP headers. The q-value is rendered with at most 3 fractional digits
  /// per RFC 9110 12.4.2.
  String encode() {
    return quality == 1.0 ? encoding : '$encoding;q=${formatQValue(quality!)}';
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
