import 'dart:convert';

import 'package:collection/collection.dart';
import 'package:meta/meta.dart';

import 'language_tag.dart';

/// An extended parameter value per [RFC 8187 section 3.2][rfc8187], such as
/// the value of `filename*` in `Content-Disposition`.
///
///     ext-value   = charset "'" [ language ] "'" value-chars
///     charset     = "UTF-8" / mime-charset
///     value-chars = *( pct-encoded / attr-char )
///     pct-encoded = "%" HEXDIG HEXDIG
///     attr-char   = ALPHA / DIGIT
///                 / "!" / "#" / "$" / "&" / "+" / "-" / "."
///                 / "^" / "_" / "`" / "|" / "~"
///
/// [ExtValue.parse] accepts only the `UTF-8` charset and throws for any
/// other. RFC 8187 requires producers to use UTF-8 and dropped the
/// ISO-8859-1 support that RFC 5987 required of recipients.
///
/// [rfc8187]: https://datatracker.ietf.org/doc/html/rfc8187#section-3.2
@immutable
final class ExtValue {
  /// The decoded value.
  final String value;

  /// The language of [value], if one is given.
  final LanguageTag? language;

  /// Creates an [ExtValue].
  const ExtValue(this.value, {this.language});

  /// Parses [source] as an `ext-value`.
  ///
  /// Throws [FormatException] when [source] does not match the grammar above,
  /// names a charset other than `UTF-8`, or percent-decodes to bytes that are
  /// not valid UTF-8.
  factory ExtValue.parse(final String source) {
    final charsetEnd = source.indexOf("'");
    if (charsetEnd < 0) {
      throw FormatException("expected \"'\" after charset", source);
    }
    final languageEnd = source.indexOf("'", charsetEnd + 1);
    if (languageEnd < 0) {
      throw FormatException(
        "expected \"'\" after language",
        source,
        charsetEnd + 1,
      );
    }

    if (!equalsIgnoreAsciiCase(source.substring(0, charsetEnd), 'UTF-8')) {
      throw FormatException('charset must be UTF-8', source, 0);
    }

    final language = languageEnd == charsetEnd + 1
        ? null
        : LanguageTag.parse(source.substring(charsetEnd + 1, languageEnd));

    return ExtValue(
      utf8.decode(_decodeValueChars(source, languageEnd + 1)),
      language: language,
    );
  }

  /// The wire form, always with the `UTF-8` charset.
  ///
  /// It percent-encodes every UTF-8 byte of [value] that is not an
  /// `attr-char`.
  String encode() {
    final buffer = StringBuffer("UTF-8'${language?.encode() ?? ''}'");
    for (final byte in utf8.encode(value)) {
      if (_isAttrChar(byte)) {
        buffer.writeCharCode(byte);
      } else {
        buffer
          ..writeCharCode(_percent)
          ..write(byte.toRadixString(16).toUpperCase().padLeft(2, '0'));
      }
    }
    return buffer.toString();
  }

  @override
  bool operator ==(final Object other) =>
      identical(this, other) ||
      (other is ExtValue && value == other.value && language == other.language);

  @override
  int get hashCode => Object.hash(value, language);

  @override
  String toString() => encode();
}

const int _percent = 0x25;

List<int> _decodeValueChars(final String source, final int start) {
  final bytes = <int>[];
  var i = start;
  while (i < source.length) {
    final c = source.codeUnitAt(i);
    if (c == _percent) {
      if (i + 2 >= source.length) {
        throw FormatException('truncated percent escape', source, i);
      }
      final high = _hexValue(source.codeUnitAt(i + 1));
      final low = _hexValue(source.codeUnitAt(i + 2));
      if (high < 0 || low < 0) {
        throw FormatException('invalid percent escape', source, i);
      }
      bytes.add(high << 4 | low);
      i += 3;
    } else if (_isAttrChar(c)) {
      bytes.add(c);
      i++;
    } else {
      throw FormatException('character not allowed in value-chars', source, i);
    }
  }
  return bytes;
}

/// The value of the hex digit [c], or -1 if [c] is not a hex digit.
int _hexValue(final int c) {
  if (c >= 0x30 && c <= 0x39) return c - 0x30; // 0-9
  if (c >= 0x41 && c <= 0x46) return c - 0x37; // A-F
  if (c >= 0x61 && c <= 0x66) return c - 0x57; // a-f
  return -1;
}

bool _isAttrChar(final int c) {
  if (c >= 0x41 && c <= 0x5A) return true; // A-Z
  if (c >= 0x61 && c <= 0x7A) return true; // a-z
  if (c >= 0x30 && c <= 0x39) return true; // 0-9
  switch (c) {
    case 0x21: // !
    case 0x23: // #
    case 0x24: // $
    case 0x26: // &
    case 0x2B: // +
    case 0x2D: // -
    case 0x2E: // .
    case 0x5E: // ^
    case 0x5F: // _
    case 0x60: // `
    case 0x7C: // |
    case 0x7E: // ~
      return true;
  }
  return false;
}
