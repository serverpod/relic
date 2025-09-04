import 'package:collection/collection.dart';

import '../../../../relic.dart';
import '../../extension/string_list_extensions.dart';

/// A class representing the HTTP Accept-Encoding header.
///
/// This header specifies the content encoding that the client can understand.
final class AcceptEncodingHeader {
  static const codec = HeaderCodec(AcceptEncodingHeader.parse, __encode);
  static List<String> __encode(final AcceptEncodingHeader value) =>
      [value._encode()];

  /// The list of encodings that are accepted.
  final List<EncodingQuality> encodings;

  /// A boolean value indicating whether the Accept-Encoding header is a wildcard.
  final bool isWildcard;

  /// Constructs an instance of [AcceptEncodingHeader] with the given encodings.
  AcceptEncodingHeader.encodings({required this.encodings})
      : assert(encodings.isNotEmpty),
        isWildcard = false;

  /// Constructs an instance of [AcceptEncodingHeader] with a wildcard encoding.
  const AcceptEncodingHeader.wildcard()
      : encodings = const [],
        isWildcard = true;

  /// Parses the Accept-Encoding header value and returns an [AcceptEncodingHeader] instance.
  factory AcceptEncodingHeader.parse(final Iterable<String> values) {
    final splitValues = values.splitTrimAndFilterUnique();

    if (splitValues.isEmpty) {
      throw const FormatException('Value cannot be empty');
    }

    if (splitValues.length == 1 && splitValues.first == '*') {
      return const AcceptEncodingHeader.wildcard();
    }

    if (splitValues.length > 1 && splitValues.contains('*')) {
      throw const FormatException(
          'Wildcard (*) cannot be used with other values');
    }

    final encodings = splitValues.map((final value) {
      final encodingParts = value.split(';q=');
      final encoding = encodingParts[0].trim().toLowerCase();
      if (encoding.isEmpty) {
        throw const FormatException('Invalid encoding');
      }
      double? quality;
      if (encodingParts.length > 1) {
        final value = double.tryParse(encodingParts[1].trim());
        if (value == null || value < 0 || value > 1) {
          throw const FormatException('Invalid quality value');
        }
        quality = value;
      }
      return EncodingQuality(encoding, quality);
    }).toList();

    return AcceptEncodingHeader.encodings(encodings: encodings);
  }

  /// Converts the [AcceptEncodingHeader] instance into a string representation suitable for HTTP headers.

  String _encode() =>
      isWildcard ? '*' : encodings.map((final e) => e._encode()).join(', ');

  @override
  bool operator ==(final Object other) =>
      identical(this, other) ||
      other is AcceptEncodingHeader &&
          isWildcard == other.isWildcard &&
          const ListEquality<EncodingQuality>()
              .equals(encodings, other.encodings);

  @override
  int get hashCode => Object.hash(
      isWildcard, const ListEquality<EncodingQuality>().hash(encodings));

  @override
  String toString() => 'AcceptEncodingHeader(encodings: $encodings)';
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

  /// Converts the [EncodingQuality] instance into a string representation suitable for HTTP headers.
  String _encode() => quality == 1.0 ? encoding : '$encoding;q=$quality';

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
