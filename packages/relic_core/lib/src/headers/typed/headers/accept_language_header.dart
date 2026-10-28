import 'dart:typed_data';

import '../../../../relic_core.dart';
import '../primitives/byte_scanner.dart' show latin1Bytes;
import 'util/cookie_util.dart' show isTrimWhitespace;
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
  ///
  /// Elements are split on commas across every field, trimmed, dropped
  /// when empty and kept once each. One element that is `*` is the
  /// wildcard, and `*` beside a language is an error.
  static AcceptLanguageHeader _parseFields(final List<Uint8List> fields) {
    // Each kept element as field index, start and end, in order.
    final elements = <int>[];
    for (var f = 0; f < fields.length; f++) {
      final bytes = fields[f];
      final length = bytes.length;
      var start = 0;
      while (start <= length) {
        var end = start;
        while (end < length && bytes[end] != 0x2C) {
          end++;
        }
        final next = end + 1;
        while (start < end && isTrimWhitespace(bytes[start])) {
          start++;
        }
        while (end > start && isTrimWhitespace(bytes[end - 1])) {
          end--;
        }
        if (start < end && !_seen(fields, elements, f, start, end)) {
          elements
            ..add(f)
            ..add(start)
            ..add(end);
        }
        start = next;
      }
    }
    final count = elements.length ~/ 3;
    if (count == 0) {
      throw const FormatException('Value cannot be empty');
    }
    var wildcards = 0;
    for (var i = 0; i < count; i++) {
      final start = elements[i * 3 + 1];
      if (elements[i * 3 + 2] - start == 1 &&
          fields[elements[i * 3]][start] == 0x2A) {
        wildcards++;
      }
    }
    if (wildcards > 0) {
      if (count == 1) return const AcceptLanguageHeader.wildcard();
      throw const FormatException(
        'Wildcard (*) cannot be used with other values',
      );
    }
    final languages = List<LanguageQuality>.generate(
      count,
      (final i) => LanguageQuality._parseBytes(
        fields[elements[i * 3]],
        elements[i * 3 + 1],
        elements[i * 3 + 2],
      ),
      growable: false,
    );
    return AcceptLanguageHeader._owned(languages);
  }

  /// Whether `fields[f][start..end)` equals an element already in
  /// [elements].
  static bool _seen(
    final List<Uint8List> fields,
    final List<int> elements,
    final int f,
    final int start,
    final int end,
  ) {
    final bytes = fields[f];
    final length = end - start;
    for (var e = 0; e < elements.length; e += 3) {
      final other = fields[elements[e]];
      final at = elements[e + 1];
      if (elements[e + 2] - at != length) continue;
      var same = true;
      for (var i = 0; i < length; i++) {
        if (other[at + i] != bytes[start + i]) {
          same = false;
          break;
        }
      }
      if (same) return true;
    }
    return false;
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
    final bytes = latin1Bytes(value);
    return LanguageQuality._parseBytes(bytes, 0, bytes.length);
  }

  /// [parse] over `bytes[start..end)`.
  static LanguageQuality _parseBytes(
    final Uint8List bytes,
    final int start,
    final int end,
  ) {
    var semi = start;
    while (semi < end && bytes[semi] != 0x3B) {
      semi++;
    }
    final language = _lowerLatin1(bytes, start, _trimEnd(bytes, start, semi));
    if (language.isEmpty) {
      throw const FormatException('Invalid language');
    }

    double? quality;
    var partStart = semi + 1;
    while (partStart <= end) {
      var partEnd = partStart;
      while (partEnd < end && bytes[partEnd] != 0x3B) {
        partEnd++;
      }
      final next = partEnd + 1;
      var eq = partStart;
      while (eq < partEnd && bytes[eq] != 0x3D) {
        eq++;
      }
      if (eq < partEnd) {
        final nameStart = _trimStart(bytes, partStart, eq);
        final nameEnd = _trimEnd(bytes, nameStart, eq);
        if (nameEnd - nameStart == 1 && (bytes[nameStart] | 0x20) == 0x71) {
          final valueStart = _trimStart(bytes, eq + 1, partEnd);
          final parsed = double.tryParse(
            String.fromCharCodes(
              bytes,
              valueStart,
              _trimEnd(bytes, valueStart, partEnd),
            ),
          );
          if (parsed != null && parsed >= 0 && parsed <= 1) {
            quality = parsed;
          }
          break;
        }
      }
      partStart = next;
    }

    return LanguageQuality(language, quality);
  }

  static int _trimStart(final Uint8List bytes, int start, final int end) {
    while (start < end && isTrimWhitespace(bytes[start])) {
      start++;
    }
    return start;
  }

  static int _trimEnd(final Uint8List bytes, final int start, int end) {
    while (end > start && isTrimWhitespace(bytes[end - 1])) {
      end--;
    }
    return end;
  }

  /// `bytes[start..end)` as a string in lower case, the way
  /// `String.toLowerCase` lowers Latin-1 text.
  static String _lowerLatin1(
    final Uint8List bytes,
    final int start,
    final int end,
  ) {
    var i = start;
    while (i < end && !_isUpper(bytes[i])) {
      i++;
    }
    if (i == end) return String.fromCharCodes(bytes, start, end);
    final lowered = Uint8List(end - start);
    for (var j = 0; j < lowered.length; j++) {
      final b = bytes[start + j];
      lowered[j] = _isUpper(b) ? b + 0x20 : b;
    }
    return String.fromCharCodes(lowered);
  }

  /// Whether [b] is an upper-case Latin-1 letter with a lower-case form
  /// 0x20 above it: A-Z and the accented capitals, less the multiplication
  /// sign in their midst.
  static bool _isUpper(final int b) =>
      (b >= 0x41 && b <= 0x5A) || (b >= 0xC0 && b <= 0xDE && b != 0xD7);

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
