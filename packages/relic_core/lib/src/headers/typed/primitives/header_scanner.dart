import 'token.dart';

/// A cursor-based scanner for HTTP header field values.
///
/// Provides the lexer primitives every typed header parser needs:
///
/// * RFC 9110 `OWS` skipping ([skipOws]).
/// * `token` reading ([readToken], [tryReadToken]).
/// * `quoted-string` reading with `quoted-pair` unescaping
///   ([readQuotedString], [tryReadQuotedString]).
/// * The canonical `token / quoted-string` alternation
///   ([readTokenOrQuotedString], [tryReadTokenOrQuotedString]).
/// * Quote-aware top-level scanning ([indexOfTopLevel], [splitTopLevel]) so
///   list and parameter separators inside a `quoted-string` are not treated
///   as structural delimiters.
///
/// All methods throw [FormatException] on malformed input, reporting the
/// scanner's current [position] within [source].
final class HeaderScanner {
  /// The full source string being scanned.
  final String source;

  int _pos = 0;

  /// Creates a scanner positioned at the start of [source].
  HeaderScanner(this.source);

  /// The current cursor position (0-based, inclusive).
  int get position => _pos;

  /// Move the cursor. Must be within `[0, source.length]`.
  set position(final int p) {
    RangeError.checkValueInInterval(p, 0, source.length, 'position');
    _pos = p;
  }

  /// True when the cursor has reached the end of [source].
  bool get atEnd => _pos >= source.length;

  /// Number of code units remaining after the cursor.
  int get remaining => source.length - _pos;

  /// Returns the code unit at the cursor, or `-1` if at end.
  int peek() => _pos < source.length ? source.codeUnitAt(_pos) : -1;

  /// Consumes [char] if it is at the cursor. Returns true if consumed.
  bool tryConsume(final int char) {
    if (peek() != char) return false;
    _pos++;
    return true;
  }

  /// Consumes [char] at the cursor, otherwise throws [FormatException].
  void expect(final int char) {
    if (!tryConsume(char)) {
      throw _error("expected '${String.fromCharCode(char)}'");
    }
  }

  /// Skips RFC 9110 `OWS = *( SP / HTAB )` at the cursor.
  void skipOws() {
    while (_pos < source.length) {
      final c = source.codeUnitAt(_pos);
      if (c != 0x20 && c != 0x09) break;
      _pos++;
    }
  }

  /// Reads a `token` (RFC 9110 5.6.2) starting at the cursor and advances
  /// past it. Returns the token characters, or `null` if no `tchar` is at
  /// the cursor.
  String? tryReadToken() {
    final start = _pos;
    while (_pos < source.length && Token.isTchar(source.codeUnitAt(_pos))) {
      _pos++;
    }
    return _pos == start ? null : source.substring(start, _pos);
  }

  /// Reads a `token`, throwing [FormatException] if no `tchar` is at the
  /// cursor.
  String readToken() => tryReadToken() ?? (throw _error('token expected'));

  /// Reads a `quoted-string` (RFC 9110 5.6.4) starting at the cursor and
  /// returns its unescaped contents (interior `quoted-pair`s decoded).
  ///
  ///     quoted-string  = DQUOTE *( qdtext / quoted-pair ) DQUOTE
  ///     qdtext         = HTAB / SP / %x21 / %x23-5B / %x5D-7E / obs-text
  ///     quoted-pair    = "\" ( HTAB / SP / VCHAR / obs-text )
  ///
  /// Returns `null` (without advancing) if the cursor is not at `"`.
  /// Throws [FormatException] on a malformed or unterminated quoted-string;
  /// the cursor is rewound to the opening quote in that case.
  String? tryReadQuotedString() {
    if (peek() != _dquote) return null;
    final start = _pos;
    _pos++; // consume opening "
    final buf = StringBuffer();
    while (_pos < source.length) {
      final c = source.codeUnitAt(_pos);
      if (c == _dquote) {
        _pos++;
        return buf.toString();
      }
      if (c == _backslash) {
        _pos++;
        if (_pos >= source.length) {
          _pos = start;
          throw _error('unterminated quoted-pair', start);
        }
        final esc = source.codeUnitAt(_pos);
        if (!_isQuotedPairTarget(esc)) {
          _pos = start;
          throw _error('invalid quoted-pair', start);
        }
        buf.writeCharCode(esc);
        _pos++;
        continue;
      }
      if (!_isQdtext(c)) {
        _pos = start;
        throw _error('invalid character in quoted-string', start);
      }
      buf.writeCharCode(c);
      _pos++;
    }
    _pos = start;
    throw _error('unterminated quoted-string', start);
  }

  /// Reads a `quoted-string`, throwing [FormatException] if the cursor is
  /// not at `"`.
  String readQuotedString() =>
      tryReadQuotedString() ?? (throw _error('quoted-string expected'));

  /// Reads either a `quoted-string` (preferred when the cursor is at `"`) or
  /// a `token`. This is the RFC 9110 `token / quoted-string` alternation
  /// used pervasively for parameter values.
  ///
  /// Returns the unescaped value, or `null` if neither is at the cursor.
  String? tryReadTokenOrQuotedString() {
    if (peek() == _dquote) return tryReadQuotedString();
    return tryReadToken();
  }

  /// Like [tryReadTokenOrQuotedString] but throws if neither is present.
  String readTokenOrQuotedString() =>
      tryReadTokenOrQuotedString() ??
      (throw _error('token or quoted-string expected'));

  /// Returns the offset of the next occurrence of [char] at the top level
  /// (i.e. not inside a `quoted-string`), or `-1` if not found before the end
  /// of [source]. Does not advance the cursor.
  ///
  /// Throws [FormatException] if a `quoted-string` encountered during the
  /// scan is malformed; the cursor is left at its original position.
  int indexOfTopLevel(final int char) {
    final saved = _pos;
    try {
      while (_pos < source.length) {
        final c = source.codeUnitAt(_pos);
        if (c == char) return _pos;
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

  /// Yields the top-level substrings of [source] (from the cursor to end)
  /// separated by [separator], skipping over `quoted-string`s and trimming
  /// surrounding `OWS` from each yielded element.
  ///
  /// An empty source yields no elements. A trailing or leading [separator] or
  /// an empty element between two separators yields an empty string at that
  /// position. Iteration advances the cursor; after the last element the
  /// cursor is at [source].length. Throws [FormatException] if a
  /// `quoted-string` is malformed.
  Iterable<String> splitTopLevel(final int separator) sync* {
    if (atEnd) return;
    while (true) {
      skipOws();
      final elementStart = _pos;
      final stop = indexOfTopLevel(separator);
      if (stop < 0) {
        yield _rtrimOws(source.substring(elementStart));
        _pos = source.length;
        return;
      }
      yield _rtrimOws(source.substring(elementStart, stop));
      _pos = stop + 1;
    }
  }

  FormatException _error(final String message, [final int? offset]) =>
      FormatException(message, source, offset ?? _pos);
}

const int _dquote = 0x22;
const int _backslash = 0x5C;

bool _isQdtext(final int c) {
  // qdtext = HTAB / SP / %x21 / %x23-5B / %x5D-7E / obs-text
  if (c == 0x09) return true;
  if (c == 0x20) return true;
  if (c == 0x21) return true;
  if (c >= 0x23 && c <= 0x5B) return true;
  if (c >= 0x5D && c <= 0x7E) return true;
  if (c >= 0x80 && c <= 0xFF) return true; // obs-text
  return false;
}

bool _isQuotedPairTarget(final int c) {
  // quoted-pair = "\" ( HTAB / SP / VCHAR / obs-text )
  if (c == 0x09) return true;
  if (c == 0x20) return true;
  if (c >= 0x21 && c <= 0x7E) return true; // VCHAR
  if (c >= 0x80 && c <= 0xFF) return true; // obs-text
  return false;
}

String _rtrimOws(final String s) {
  var end = s.length;
  while (end > 0) {
    final c = s.codeUnitAt(end - 1);
    if (c != 0x20 && c != 0x09) break;
    end--;
  }
  return end == s.length ? s : s.substring(0, end);
}
