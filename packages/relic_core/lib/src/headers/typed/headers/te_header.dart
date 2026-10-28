import 'dart:typed_data';

import 'package:collection/collection.dart';

import '../../../../relic_core.dart';
import '../primitives/byte_fields.dart';
import '../primitives/byte_scanner.dart' show latin1Bytes;
import 'util/qvalue.dart';

/// A class representing the HTTP TE header.
///
/// The TE header indicates the transfer encodings the client is willing to accept,
/// optionally with quality values.
final class TEHeader {
  static const codec = HeaderCodec.fields(_parseFields, __encode);
  static List<String> __encode(final TEHeader value) => [value._encode()];

  /// The list of encodings with their quality values.
  final List<TeQuality> encodings;

  /// Constructs a [TEHeader] instance with the specified list of encodings.
  TEHeader.encodings(final List<TeQuality> encodings)
    : assert(encodings.isNotEmpty),
      encodings = List.unmodifiable(encodings);

  /// Parses the TE header value and returns a [TEHeader] instance.
  ///
  /// This method processes the TE header and extracts the list of encodings
  /// with their quality values.
  factory TEHeader.parse(final Iterable<String> values) =>
      _parseFields([for (final value in values) latin1Bytes(value)]);

  /// Takes [encodings], a list the parser built, as its own.
  const TEHeader._(this.encodings);

  /// The header from the wire bytes of its [fields].
  ///
  /// Per RFC 9110 12.4.2 the weight parameter is `q`, case-insensitive,
  /// with OWS allowed around the surrounding `;` and `=`.
  static TEHeader _parseFields(final List<Uint8List> fields) {
    final elements = splitFieldsUnique(fields);
    if (elements.isEmpty) {
      throw const FormatException('Value cannot be empty');
    }
    return TEHeader._(
      List.generate(elements.length, (final i) {
        final element = elements[i];
        var semi = indexOfByte(element, 0x3B);
        if (semi < 0) semi = element.length;
        final encoding = lowerTextOf(element, 0, trimEnd(element, 0, semi));
        if (encoding.isEmpty) {
          throw const FormatException('Invalid encoding');
        }
        return TeQuality(encoding, qualityParameter(element, semi + 1));
      }, growable: false),
    );
  }

  /// Converts the [TEHeader] instance into a string representation
  /// suitable for HTTP headers.

  String _encode() => encodings.map((final e) => e._encode()).join(', ');

  @override
  bool operator ==(final Object other) =>
      identical(this, other) ||
      other is TEHeader &&
          const ListEquality<TeQuality>().equals(encodings, other.encodings);

  @override
  int get hashCode => const ListEquality<TeQuality>().hash(encodings);

  @override
  String toString() => 'TEHeader(encodings: $encodings)';
}

/// A class representing a transfer encoding with an optional quality value.
class TeQuality {
  /// The encoding value.
  final String encoding;

  /// The quality value (default is 1.0).
  final double? quality;

  /// Constructs an instance of [TeQuality].
  TeQuality(this.encoding, [final double? quality]) : quality = quality ?? 1.0;

  /// Converts the [TeQuality] instance into a string representation suitable
  /// for HTTP headers. The q-value is rendered with at most 3 fractional
  /// digits per RFC 9110 12.4.2.
  String _encode() =>
      quality == 1.0 ? encoding : '$encoding;q=${formatQValue(quality!)}';

  @override
  bool operator ==(final Object other) =>
      identical(this, other) ||
      other is TeQuality &&
          encoding == other.encoding &&
          quality == other.quality;

  @override
  int get hashCode => Object.hash(encoding, quality);

  @override
  String toString() => 'TeQuality(encoding: $encoding, quality: $quality)';
}
