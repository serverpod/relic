import 'dart:typed_data';

import '../../../../relic_core.dart';
import 'util/cookie_util.dart' show isTrimWhitespace;
import 'util/qvalue.dart';
import 'wildcard_list_header.dart';

/// A class representing the HTTP Accept-Language header.
///
/// This header specifies the natural languages that are preferred in the response.
final class AcceptLanguageHeader extends WildcardListHeader<LanguageQuality> {
  static const codec = HeaderCodec(_parse, _encode, decodeBytes: _parseBytes);

  /// Constructs an instance with the given languages
  AcceptLanguageHeader.languages(super.languages);

  /// Constructs an instance with a wildcard language
  const AcceptLanguageHeader.wildcard() : super.wildcard();

  AcceptLanguageHeader._owned(super.languages) : super.owned();

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
      return AcceptLanguageHeader._owned(parsed.values);
    }
  }

  /// [_parse] over the wire bytes of a single field.
  ///
  /// Declines a byte at or above 0x80, where lower-casing is more than
  /// ASCII, so the text path reads the value as Latin-1 the way it always
  /// did. Elements are split on commas, trimmed, dropped when empty and
  /// kept once each, as the text path does.
  static AcceptLanguageHeader? _parseBytes(final Uint8List bytes) {
    final length = bytes.length;
    for (var i = 0; i < length; i++) {
      if (bytes[i] >= 0x80) return null;
    }
    // Each kept element as start and end, in order.
    final elements = <int>[];
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
      if (start < end && !_seen(bytes, elements, start, end)) {
        elements
          ..add(start)
          ..add(end);
      }
      start = next;
    }
    final count = elements.length ~/ 2;
    if (count == 0) {
      throw const FormatException('Value cannot be empty');
    }
    var wildcards = 0;
    for (var i = 0; i < count; i++) {
      if (elements[i * 2 + 1] - elements[i * 2] == 1 &&
          bytes[elements[i * 2]] == 0x2A) {
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
        bytes,
        elements[i * 2],
        elements[i * 2 + 1],
      ),
      growable: false,
    );
    return AcceptLanguageHeader._owned(languages);
  }

  /// Whether `bytes[start..end)` equals an element already in [elements].
  static bool _seen(
    final Uint8List bytes,
    final List<int> elements,
    final int start,
    final int end,
  ) {
    final length = end - start;
    for (var e = 0; e < elements.length; e += 2) {
      final at = elements[e];
      if (elements[e + 1] - at != length) continue;
      var same = true;
      for (var i = 0; i < length; i++) {
        if (bytes[at + i] != bytes[start + i]) {
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
      // A malformed or out-of-range weight is treated as absent (defaulting to
      // 1.0) rather than rejecting the whole header: the client did list this
      // entry, so it is acceptable; only the unparseable preference is dropped
      // (RFC 9110 12.4.2; robustness on received headers).
      if (parsed != null && parsed >= 0 && parsed <= 1) {
        quality = parsed;
      }
      break;
    }

    return LanguageQuality(language, quality);
  }

  /// [parse] over `bytes[start..end)`, ASCII only.
  static LanguageQuality _parseBytes(
    final Uint8List bytes,
    final int start,
    final int end,
  ) {
    var semi = start;
    while (semi < end && bytes[semi] != 0x3B) {
      semi++;
    }
    final language = _lowerAscii(bytes, start, _trimEnd(bytes, start, semi));
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

  /// `bytes[start..end)` as a string with ASCII letters in lower case.
  static String _lowerAscii(
    final Uint8List bytes,
    final int start,
    final int end,
  ) {
    var i = start;
    while (i < end && (bytes[i] < 0x41 || bytes[i] > 0x5A)) {
      i++;
    }
    if (i == end) return String.fromCharCodes(bytes, start, end);
    final lowered = Uint8List(end - start);
    for (var j = 0; j < lowered.length; j++) {
      final b = bytes[start + j];
      lowered[j] = b >= 0x41 && b <= 0x5A ? b | 0x20 : b;
    }
    return String.fromCharCodes(lowered);
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
