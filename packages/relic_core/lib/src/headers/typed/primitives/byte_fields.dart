/// Helpers over the wire bytes of header fields, for the typed header
/// parsers.
///
/// Text comes out as Latin-1, one code unit per byte (RFC 9110 5.5), the
/// way `String.fromCharCodes` reads a byte list.
library;

import 'dart:typed_data';

import 'package:relic_headers/relic_headers.dart' show HeaderName;

/// The text of `bytes[start..end)`.
String textOf(Uint8List bytes, [int start = 0, int? end]) =>
    String.fromCharCodes(bytes, start, end ?? bytes.length);

/// The text of `bytes[start..end)` in lower case, the way
/// `String.toLowerCase` lowers Latin-1 text.
String lowerTextOf(Uint8List bytes, [int start = 0, int? end]) {
  end ??= bytes.length;
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

/// Whether [b] is an upper-case Latin-1 letter with a lower-case form 0x20
/// above it: A-Z and the accented capitals, less the multiplication sign in
/// their midst.
bool _isUpper(int b) =>
    (b >= 0x41 && b <= 0x5A) || (b >= 0xC0 && b <= 0xDE && b != 0xD7);

/// Whether [b] is one of the characters `String.trim` strips, among those a
/// byte can be.
bool isTrimByte(int b) =>
    b == 0x20 || (b >= 0x09 && b <= 0x0D) || b == 0x85 || b == 0xA0;

/// The first offset at or after [start] whose byte is not trimmed, up to
/// [end].
int trimStart(Uint8List bytes, int start, int end) {
  while (start < end && isTrimByte(bytes[start])) {
    start++;
  }
  return start;
}

/// The offset after the last byte before [end] that is not trimmed, down
/// to [start].
int trimEnd(Uint8List bytes, int start, int end) {
  while (end > start && isTrimByte(bytes[end - 1])) {
    end--;
  }
  return end;
}

/// `bytes[start..end)` with the trimmed characters left out, as a view.
Uint8List trimmed(Uint8List bytes, [int start = 0, int? end]) {
  end ??= bytes.length;
  final s = trimStart(bytes, start, end);
  return Uint8List.sublistView(bytes, s, trimEnd(bytes, s, end));
}

/// The offset of the first [byte] in `bytes[start..end)`, or -1.
int indexOfByte(Uint8List bytes, int byte, [int start = 0, int? end]) {
  end ??= bytes.length;
  while (start < end) {
    if (bytes[start] == byte) return start;
    start++;
  }
  return -1;
}

/// Whether [a] and [b] hold the same bytes.
bool bytesEqual(Uint8List a, Uint8List b) {
  if (a.length != b.length) return false;
  for (var i = 0; i < a.length; i++) {
    if (a[i] != b[i]) return false;
  }
  return true;
}

/// Whether `bytes[start..end)` spells [ascii], ASCII letters compared
/// without regard to case.
bool equalsIgnoreAsciiCase(Uint8List bytes, int start, int end, String ascii) {
  if (end - start != ascii.length) return false;
  for (var i = 0; i < ascii.length; i++) {
    var a = bytes[start + i];
    var b = ascii.codeUnitAt(i);
    if (a >= 0x41 && a <= 0x5A) a += 0x20;
    if (b >= 0x41 && b <= 0x5A) b += 0x20;
    if (a != b) return false;
  }
  return true;
}

/// The trimmed, non-empty elements of [bytes] split on [separator], each
/// kept once, as views in order.
///
/// What `splitTrimAndFilterUnique` does on text.
List<Uint8List> splitUnique(Uint8List bytes, [int separator = 0x2C]) {
  final elements = <Uint8List>[];
  _splitInto(bytes, separator, elements);
  return elements;
}

/// The trimmed, non-empty elements of [bytes] split on [separator], as
/// views in order, repeats kept.
///
/// What `splitAndTrim` does on text.
List<Uint8List> splitAll(Uint8List bytes, [int separator = 0x2C]) {
  final elements = <Uint8List>[];
  _splitInto(bytes, separator, elements, unique: false);
  return elements;
}

/// [splitAll] over every field.
List<Uint8List> splitFieldsAll(List<Uint8List> fields, [int separator = 0x2C]) {
  final elements = <Uint8List>[];
  for (final field in fields) {
    _splitInto(field, separator, elements, unique: false);
  }
  return elements;
}

/// [splitUnique] over every field, elements kept once across all of them.
List<Uint8List> splitFieldsUnique(
  List<Uint8List> fields, [
  int separator = 0x2C,
]) {
  if (fields.length == 1) return splitUnique(fields[0], separator);
  final elements = <Uint8List>[];
  for (final field in fields) {
    _splitInto(field, separator, elements);
  }
  return elements;
}

void _splitInto(
  Uint8List bytes,
  int separator,
  List<Uint8List> elements, {
  bool unique = true,
}) {
  final length = bytes.length;
  var start = 0;
  while (start <= length) {
    var end = indexOfByte(bytes, separator, start, length);
    final next = end < 0 ? length + 1 : end + 1;
    if (end < 0) end = length;
    final s = trimStart(bytes, start, end);
    final e = trimEnd(bytes, s, end);
    if (s < e) {
      final element = Uint8List.sublistView(bytes, s, e);
      var seen = false;
      if (unique) {
        for (final other in elements) {
          if (bytesEqual(other, element)) {
            seen = true;
            break;
          }
        }
      }
      if (!seen) elements.add(element);
    }
    start = next;
  }
}

/// Whether every byte of `bytes[start..end)` is a `tchar` (RFC 9110
/// 5.6.2) and there is at least one.
bool isToken(Uint8List bytes, [int start = 0, int? end]) {
  end ??= bytes.length;
  if (start >= end) return false;
  for (var i = start; i < end; i++) {
    if (!HeaderName.isTchar(bytes[i])) return false;
  }
  return true;
}

/// The text of [bytes] when it is a `token`, else a [FormatException] the
/// way `Token.validate` throws it.
String tokenText(Uint8List bytes) {
  if (!isToken(bytes)) {
    throw FormatException(
      'Not a valid HTTP token (RFC 9110 5.6.2)',
      textOf(bytes),
    );
  }
  return textOf(bytes);
}

/// Whether [element] is the single byte `*`.
bool isWildcardElement(Uint8List element) =>
    element.length == 1 && element[0] == 0x2A;

/// The `q` parameter among the `;`-separated parameters of [element] from
/// [from] on, RFC 9110 12.4.2, or null when absent or not a weight in
/// `[0, 1]`.
///
/// The parameter name is matched without regard to case, with OWS allowed
/// around `;` and `=`. The first parameter named `q` decides.
double? qualityParameter(Uint8List element, int from) {
  final end = element.length;
  while (from <= end) {
    var partEnd = indexOfByte(element, 0x3B, from, end);
    final next = partEnd < 0 ? end + 1 : partEnd + 1;
    if (partEnd < 0) partEnd = end;
    final eq = indexOfByte(element, 0x3D, from, partEnd);
    if (eq >= 0) {
      final nameStart = trimStart(element, from, eq);
      final nameEnd = trimEnd(element, nameStart, eq);
      if (equalsIgnoreAsciiCase(element, nameStart, nameEnd, 'q')) {
        final valueStart = trimStart(element, eq + 1, partEnd);
        final parsed = double.tryParse(
          textOf(element, valueStart, trimEnd(element, valueStart, partEnd)),
        );
        // A malformed or out-of-range weight is treated as absent, so the
        // entry the client listed stays acceptable at the default weight
        // (RFC 9110 12.4.2, robustness on received headers).
        if (parsed != null && parsed >= 0 && parsed <= 1) return parsed;
        return null;
      }
    }
    from = next;
  }
  return null;
}

/// The run of ASCII digits that is all of `bytes[start..end)` as an int,
/// or null for anything else. Up to 18 digits, which always fits.
int? digitsOf(Uint8List bytes, [int start = 0, int? end]) {
  end ??= bytes.length;
  if (start >= end || end - start > 18) return null;
  var value = 0;
  for (var i = start; i < end; i++) {
    final b = bytes[i];
    if (b < 0x30 || b > 0x39) return null;
    value = value * 10 + (b - 0x30);
  }
  return value;
}
