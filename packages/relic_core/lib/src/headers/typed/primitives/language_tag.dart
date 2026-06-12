import 'package:meta/meta.dart';

/// A BCP 47 language tag per [RFC 5646][rfc5646], used by `Content-Language`
/// (RFC 9110 8.5) and `Accept-Language` (RFC 9110 12.5.4).
///
///     Language-Tag  = langtag / privateuse / grandfathered
///
/// BCP 47 tags are matched case-insensitively, but conventional output uses
/// title casing for script subtags, uppercase for ALPHA region subtags, and
/// lowercase for everything else. This class normalizes the case of each
/// subtag in [encode] without reordering them, so a correctly-ordered tag
/// such as `EN-Latn-us` round-trips as `en-Latn-US`. Subtags supplied in the
/// wrong order (e.g. region before script) are rejected, not reordered.
///
/// Equality is case-insensitive (operates on the canonical form).
///
/// [rfc5646]: https://datatracker.ietf.org/doc/html/rfc5646
@immutable
final class LanguageTag {
  /// The canonical-cased subtags as they appear separated by `-` on the wire.
  final List<String> subtags;

  const LanguageTag._(this.subtags);

  /// Parses [source] as a BCP 47 language tag.
  ///
  /// Throws [FormatException] when [source] is empty, contains an empty
  /// subtag, or does not match the grammar above.
  factory LanguageTag.parse(final String source) {
    if (source.isEmpty) {
      throw const FormatException('language-tag cannot be empty');
    }

    final raw = source.split('-');
    for (final s in raw) {
      if (s.isEmpty) {
        throw FormatException('empty subtag', source);
      }
      if (s.length > 8) {
        throw FormatException('subtag too long', s);
      }
      for (var i = 0; i < s.length; i++) {
        if (!_isAlphaNum(s.codeUnitAt(i))) {
          throw FormatException('subtag must be alphanumeric', s);
        }
      }
    }

    final lowerSource = source.toLowerCase();
    if (_irregularGrandfathered.contains(lowerSource)) {
      return LanguageTag._(List.unmodifiable(lowerSource.split('-')));
    }

    if (_lower(raw[0]) == 'x') {
      if (raw.length < 2) {
        throw FormatException('private-use needs subtags', source);
      }
      for (var i = 1; i < raw.length; i++) {
        if (raw[i].length > 8) {
          throw FormatException('private-use subtag too long', raw[i]);
        }
      }
      return LanguageTag._(List.unmodifiable(raw.map(_lower)));
    }

    final canonical = <String>[];
    var i = 0;

    final lang = raw[i];
    if (!_isAllAlpha(lang) || lang.length < 2 || lang.length > 8) {
      throw FormatException('language subtag must be 2-8 ALPHA', lang);
    }
    canonical.add(_lower(lang));
    i++;

    if (lang.length <= 3) {
      var extlangs = 0;
      while (i < raw.length &&
          extlangs < 3 &&
          raw[i].length == 3 &&
          _isAllAlpha(raw[i])) {
        canonical.add(_lower(raw[i]));
        i++;
        extlangs++;
      }
    }

    if (i < raw.length && raw[i].length == 4 && _isAllAlpha(raw[i])) {
      canonical.add(_titleCase(raw[i]));
      i++;
    }

    if (i < raw.length) {
      final r = raw[i];
      if (r.length == 2 && _isAllAlpha(r)) {
        canonical.add(_upper(r));
        i++;
      } else if (r.length == 3 && _isAllDigit(r)) {
        canonical.add(r);
        i++;
      }
    }

    // BCP 47 (RFC 5646 2.2.5): the same variant subtag MUST NOT appear twice.
    final seenVariants = <String>{};
    while (i < raw.length && _isVariant(raw[i])) {
      final variant = _lower(raw[i]);
      if (!seenVariants.add(variant)) {
        throw FormatException('duplicate variant subtag "$variant"', source);
      }
      canonical.add(variant);
      i++;
    }

    // BCP 47 (RFC 5646 2.2.6): a given extension singleton MUST NOT repeat.
    final seenSingletons = <String>{};
    while (i < raw.length &&
        raw[i].length == 1 &&
        _isExtensionSingleton(raw[i].codeUnitAt(0))) {
      final singleton = _lower(raw[i]);
      if (!seenSingletons.add(singleton)) {
        throw FormatException(
          'duplicate extension singleton "$singleton"',
          source,
        );
      }
      canonical.add(singleton);
      i++;
      var subCount = 0;
      while (i < raw.length &&
          raw[i].length >= 2 &&
          raw[i].length <= 8 &&
          _isAllAlphaNum(raw[i])) {
        canonical.add(_lower(raw[i]));
        i++;
        subCount++;
      }
      if (subCount == 0) {
        throw FormatException(
          'extension singleton needs at least one subtag',
          source,
        );
      }
    }

    if (i < raw.length && _lower(raw[i]) == 'x') {
      canonical.add('x');
      i++;
      if (i >= raw.length) {
        throw FormatException('private-use needs subtags', source);
      }
      while (i < raw.length) {
        canonical.add(_lower(raw[i]));
        i++;
      }
    }

    if (i < raw.length) {
      throw FormatException(
        'unrecognized subtag "${raw[i]}" at position $i',
        source,
      );
    }

    return LanguageTag._(List.unmodifiable(canonical));
  }

  /// The wire form of this tag, joined with `-`, in canonical case.
  String encode() => subtags.join('-');

  @override
  bool operator ==(final Object other) =>
      identical(this, other) ||
      (other is LanguageTag && _listEqual(subtags, other.subtags));

  @override
  int get hashCode => Object.hashAll(subtags);

  @override
  String toString() => encode();
}

bool _isAlpha(final int c) =>
    (c >= 0x41 && c <= 0x5A) || (c >= 0x61 && c <= 0x7A);

bool _isDigit(final int c) => c >= 0x30 && c <= 0x39;

bool _isAlphaNum(final int c) => _isAlpha(c) || _isDigit(c);

bool _isAllAlpha(final String s) {
  for (var i = 0; i < s.length; i++) {
    if (!_isAlpha(s.codeUnitAt(i))) return false;
  }
  return true;
}

bool _isAllDigit(final String s) {
  for (var i = 0; i < s.length; i++) {
    if (!_isDigit(s.codeUnitAt(i))) return false;
  }
  return true;
}

bool _isAllAlphaNum(final String s) {
  for (var i = 0; i < s.length; i++) {
    if (!_isAlphaNum(s.codeUnitAt(i))) return false;
  }
  return true;
}

bool _isVariant(final String s) {
  if (s.length == 4 && _isDigit(s.codeUnitAt(0))) {
    for (var i = 1; i < s.length; i++) {
      if (!_isAlphaNum(s.codeUnitAt(i))) return false;
    }
    return true;
  }
  if (s.length >= 5 && s.length <= 8) return _isAllAlphaNum(s);
  return false;
}

bool _isExtensionSingleton(final int c) {
  // singleton = DIGIT / A-W / Y-Z / a-w / y-z (excluding 'x'/'X', which is
  // reserved for private-use).
  if (_isDigit(c)) return true;
  if (c >= 0x41 && c <= 0x57) return true;
  if (c == 0x59 || c == 0x5A) return true;
  if (c >= 0x61 && c <= 0x77) return true;
  if (c == 0x79 || c == 0x7A) return true;
  return false;
}

String _lower(final String s) {
  final buf = StringBuffer();
  for (var i = 0; i < s.length; i++) {
    final c = s.codeUnitAt(i);
    buf.writeCharCode((c >= 0x41 && c <= 0x5A) ? c + 0x20 : c);
  }
  return buf.toString();
}

String _upper(final String s) {
  final buf = StringBuffer();
  for (var i = 0; i < s.length; i++) {
    final c = s.codeUnitAt(i);
    buf.writeCharCode((c >= 0x61 && c <= 0x7A) ? c - 0x20 : c);
  }
  return buf.toString();
}

String _titleCase(final String s) {
  if (s.isEmpty) return s;
  final buf = StringBuffer();
  final c0 = s.codeUnitAt(0);
  buf.writeCharCode((c0 >= 0x61 && c0 <= 0x7A) ? c0 - 0x20 : c0);
  for (var i = 1; i < s.length; i++) {
    final c = s.codeUnitAt(i);
    buf.writeCharCode((c >= 0x41 && c <= 0x5A) ? c + 0x20 : c);
  }
  return buf.toString();
}

bool _listEqual(final List<String> a, final List<String> b) {
  if (identical(a, b)) return true;
  if (a.length != b.length) return false;
  for (var i = 0; i < a.length; i++) {
    if (a[i] != b[i]) return false;
  }
  return true;
}

/// Irregular grandfathered tags from RFC 5646 Appendix A. These do not
/// otherwise match the `langtag` grammar but remain valid BCP 47 tags.
const Set<String> _irregularGrandfathered = {
  'en-gb-oed',
  'i-ami',
  'i-bnn',
  'i-default',
  'i-enochian',
  'i-hak',
  'i-klingon',
  'i-lux',
  'i-mingo',
  'i-navajo',
  'i-pwn',
  'i-tao',
  'i-tay',
  'i-tsu',
  'sgn-be-fr',
  'sgn-be-nl',
  'sgn-ch-de',
};
