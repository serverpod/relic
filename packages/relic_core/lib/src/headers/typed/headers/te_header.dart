import 'package:collection/collection.dart';

import '../../../../relic_core.dart';
import '../../extension/string_list_extensions.dart';

/// A class representing the HTTP TE header.
///
/// The TE header indicates the transfer encodings the client is willing to accept,
/// optionally with quality values.
final class TEHeader {
  static const codec = HeaderCodec(TEHeader.parse, __encode);
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
  factory TEHeader.parse(final Iterable<String> values) {
    final splitValues = values.splitTrimAndFilterUnique();

    if (splitValues.isEmpty) {
      throw const FormatException('Value cannot be empty');
    }

    final encodings = splitValues.map((final value) {
      final parts = value.split(';');
      final encoding = parts[0].trim().toLowerCase();
      if (encoding.isEmpty) {
        throw const FormatException('Invalid encoding');
      }
      double? quality;
      // Per RFC 9110 12.4.2 the weight parameter is `q`, case-insensitive,
      // with OWS allowed around the surrounding `;` and `=`.
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
      return TeQuality(encoding, quality);
    }).toList();

    return TEHeader.encodings(encodings);
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
      quality == 1.0 ? encoding : '$encoding;q=${_formatQValue(quality!)}';

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
      other is TeQuality &&
          encoding == other.encoding &&
          quality == other.quality;

  @override
  int get hashCode => Object.hash(encoding, quality);

  @override
  String toString() => 'TeQuality(encoding: $encoding, quality: $quality)';
}
