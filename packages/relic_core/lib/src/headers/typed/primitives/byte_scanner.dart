import 'dart:convert';
import 'dart:typed_data';

import 'token.dart';

/// A cursor-based scanner over the wire bytes of a header field value.
///
/// The byte-level twin of [HeaderScanner], with the same lexer primitives:
/// `OWS` skipping, `token` and `quoted-string` reading with `quoted-pair`
/// unescaping, and quote-aware top-level splitting. Text comes out as
/// Latin-1, one code unit per byte (RFC 9110 5.5), or as UTF-8 when the
/// scanner was made with [ByteScanner.utf8].
///
/// Every method throws [FormatException] on malformed input, reporting the
/// scanner's current [position] within the source.
final class ByteScanner {
  /// The bytes being scanned.
  final Uint8List source;

  /// Whether text decodes as UTF-8 rather than Latin-1.
  final bool _utf8;

  int _pos = 0;

  /// A scanner at the start of [source], decoding text as Latin-1.
  ByteScanner(this.source) : _utf8 = false;

  /// A scanner at the start of [source], decoding text as UTF-8.
  ByteScanner.utf8(this.source) : _utf8 = true;

  /// A scanner over the Latin-1 bytes of [text].
  ///
  /// Throws [FormatException] for a code unit above 0xFF, which no header
  /// field can carry.
  factory ByteScanner.text(final String text) => ByteScanner(latin1Bytes(text));

  /// The current cursor position, 0-based.
  int get position => _pos;

  set position(final int p) {
    RangeError.checkValueInInterval(p, 0, source.length, 'position');
    _pos = p;
  }

  /// Whether the cursor has reached the end of [source].
  bool get atEnd => _pos >= source.length;

  /// The bytes left after the cursor.
  int get remaining => source.length - _pos;

  /// The byte at the cursor, or -1 at the end.
  int peek() => _pos < source.length ? source[_pos] : -1;

  /// Consumes [byte] when it is at the cursor.
  bool tryConsume(final int byte) {
    if (peek() != byte) return false;
    _pos++;
    return true;
  }

  /// Consumes [byte] at the cursor, else throws [FormatException].
  void expect(final int byte) {
    if (!tryConsume(byte)) {
      throw _error("expected '${String.fromCharCode(byte)}'");
    }
  }

  /// Skips RFC 9110 `OWS = *( SP / HTAB )` at the cursor.
  void skipOws() {
    while (_pos < source.length) {
      final c = source[_pos];
      if (c != 0x20 && c != 0x09) break;
      _pos++;
    }
  }

  /// The text of `source[start..end)`.
  String text(final int start, final int end) => _utf8
      ? utf8.decode(Uint8List.sublistView(source, start, end))
      : String.fromCharCodes(source, start, end);

  /// The text from the cursor to the end, without moving the cursor.
  String get rest => text(_pos, source.length);

  /// Reads a `token` (RFC 9110 5.6.2) at the cursor, or returns null and
  /// stays when no `tchar` is there.
  String? tryReadToken() {
    final start = _pos;
    while (_pos < source.length && Token.isTchar(source[_pos])) {
      _pos++;
    }
    return _pos == start ? null : text(start, _pos);
  }

  /// Reads a `token`, else throws [FormatException].
  String readToken() => tryReadToken() ?? (throw _error('token expected'));

  /// Reads a `quoted-string` (RFC 9110 5.6.4) at the cursor and returns its
  /// unescaped contents, or returns null and stays when the cursor is not
  /// at `"`.
  ///
  ///     quoted-string  = DQUOTE *( qdtext / quoted-pair ) DQUOTE
  ///     qdtext         = HTAB / SP / %x21 / %x23-5B / %x5D-7E / obs-text
  ///     quoted-pair    = "\" ( HTAB / SP / VCHAR / obs-text )
  ///
  /// Throws [FormatException] on a malformed or unterminated one, with the
  /// cursor back at the opening quote.
  String? tryReadQuotedString() {
    if (peek() != _dquote) return null;
    final start = _pos;
    _pos++;
    // The contents, copied only when a quoted-pair makes that necessary.
    BytesBuilder? unescaped;
    var runStart = _pos;
    while (_pos < source.length) {
      final c = source[_pos];
      if (c == _dquote) {
        final end = _pos;
        _pos++;
        if (unescaped == null) return text(runStart, end);
        unescaped.add(Uint8List.sublistView(source, runStart, end));
        return _decode(unescaped.takeBytes());
      }
      if (c == _backslash) {
        if (_pos + 1 >= source.length) {
          _pos = start;
          throw _error('unterminated quoted-pair', start);
        }
        final esc = source[_pos + 1];
        if (!_isQuotedPairTarget(esc)) {
          _pos = start;
          throw _error('invalid quoted-pair', start);
        }
        (unescaped ??= BytesBuilder(
          copy: false,
        )).add(Uint8List.sublistView(source, runStart, _pos));
        unescaped.addByte(esc);
        _pos += 2;
        runStart = _pos;
        continue;
      }
      if (!_isQdtext(c)) {
        _pos = start;
        throw _error('invalid character in quoted-string', start);
      }
      _pos++;
    }
    _pos = start;
    throw _error('unterminated quoted-string', start);
  }

  /// Reads a `quoted-string`, else throws [FormatException].
  String readQuotedString() =>
      tryReadQuotedString() ?? (throw _error('quoted-string expected'));

  /// Reads a `quoted-string` when the cursor is at `"`, else a `token`: the
  /// RFC 9110 `token / quoted-string` alternation of parameter values.
  ///
  /// Null, and no move, when neither is at the cursor.
  String? tryReadTokenOrQuotedString() {
    if (peek() == _dquote) return tryReadQuotedString();
    return tryReadToken();
  }

  /// [tryReadTokenOrQuotedString], else throws [FormatException].
  String readTokenOrQuotedString() =>
      tryReadTokenOrQuotedString() ??
      (throw _error('token or quoted-string expected'));

  /// The offset of the next [byte] outside any `quoted-string`, or -1. The
  /// cursor stays.
  ///
  /// Throws [FormatException] for a malformed `quoted-string` on the way.
  int indexOfTopLevel(final int byte) {
    final saved = _pos;
    try {
      while (_pos < source.length) {
        final c = source[_pos];
        if (c == byte) return _pos;
        if (c == _dquote) {
          tryReadQuotedString();
          continue;
        }
        _pos++;
      }
      return -1;
    } finally {
      _pos = saved;
    }
  }

  /// The top-level elements from the cursor to the end, separated by
  /// [separator] outside any `quoted-string`, each as a scanner over its
  /// bytes with surrounding `OWS` left out.
  ///
  /// An empty source has no elements. A leading, trailing or doubled
  /// separator gives an empty element. The cursor ends at the end.
  Iterable<ByteScanner> splitTopLevel(final int separator) sync* {
    if (atEnd) return;
    while (true) {
      skipOws();
      final start = _pos;
      final stop = indexOfTopLevel(separator);
      final end = stop < 0 ? source.length : stop;
      yield slice(start, _rtrimOws(start, end));
      if (stop < 0) {
        _pos = source.length;
        return;
      }
      _pos = stop + 1;
    }
  }

  /// A scanner over `source[start..end)` with this scanner's text decoding.
  ByteScanner slice(final int start, final int end) {
    final view = Uint8List.sublistView(source, start, end);
    return _utf8 ? ByteScanner.utf8(view) : ByteScanner(view);
  }

  int _rtrimOws(final int start, int end) {
    while (end > start) {
      final c = source[end - 1];
      if (c != 0x20 && c != 0x09) break;
      end--;
    }
    return end;
  }

  String _decode(final Uint8List bytes) =>
      _utf8 ? utf8.decode(bytes) : String.fromCharCodes(bytes);

  FormatException _error(final String message, [final int? offset]) =>
      FormatException(message, text(0, source.length), offset ?? _pos);
}

/// The Latin-1 bytes of [text], one per code unit.
///
/// Throws [FormatException] for a code unit above 0xFF, which no header
/// field can carry.
Uint8List latin1Bytes(final String text) {
  final bytes = Uint8List(text.length);
  for (var i = 0; i < text.length; i++) {
    final c = text.codeUnitAt(i);
    if (c > 0xFF) {
      throw FormatException('Not a Latin-1 header value', text, i);
    }
    bytes[i] = c;
  }
  return bytes;
}

const int _dquote = 0x22;
const int _backslash = 0x5C;

bool _isQdtext(final int c) {
  // qdtext = HTAB / SP / %x21 / %x23-5B / %x5D-7E / obs-text
  if (c == 0x09 || c == 0x20 || c == 0x21) return true;
  if (c >= 0x23 && c <= 0x5B) return true;
  if (c >= 0x5D && c <= 0x7E) return true;
  return c >= 0x80;
}

bool _isQuotedPairTarget(final int c) {
  // quoted-pair = "\" ( HTAB / SP / VCHAR / obs-text )
  if (c == 0x09 || c == 0x20) return true;
  if (c >= 0x21 && c <= 0x7E) return true;
  return c >= 0x80;
}
