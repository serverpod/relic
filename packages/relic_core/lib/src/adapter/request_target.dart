import 'dart:collection';
import 'dart:convert';
import 'dart:typed_data';

import '../router/normalized_path.dart';

/// The path and query of a request, as received.
///
/// Bytes first, text on demand. An adapter that parses the request line
/// hands over the bytes with [RequestTarget.fromBytes], and nothing decodes
/// until a handler asks. An adapter that already has a [Uri] hands that
/// over with [RequestTarget.fromUri], and the bytes are derived on demand.
///
/// [pathSegments] splits on `/` before percent-decoding, exactly as
/// [Uri.pathSegments] does, so an encoded separator (`%2F`) stays inside
/// its segment. The router relies on that.
final class RequestTarget {
  Uri? _uri;
  Uint8List? _pathBytes;
  Uint8List? _queryBytes;
  bool _queryBytesKnown;
  String? _path;
  String? _query;
  List<String>? _pathSegments;
  Map<String, List<String>>? _queryParametersAll;

  RequestTarget._(
    this._uri,
    this._pathBytes,
    this._queryBytes,
    this._queryBytesKnown,
  );

  /// The path and query of [uri].
  ///
  /// Its scheme, authority and fragment are ignored.
  factory RequestTarget.fromUri(Uri uri) =>
      RequestTarget._(uri, null, null, false);

  /// The percent-encoded [path] and [query] bytes of an origin-form target.
  ///
  /// [query] excludes the `?` and is null when the target has none.
  factory RequestTarget.fromBytes(Uint8List path, [Uint8List? query]) =>
      RequestTarget._(null, path, query, true);

  /// The percent-encoded path bytes.
  Uint8List get pathBytes => _pathBytes ??= ascii.encode(_uri!.path);

  /// The raw query bytes without `?`, or null when there is no query.
  Uint8List? get queryBytes {
    if (!_queryBytesKnown) {
      final uri = _uri!;
      if (uri.hasQuery) _queryBytes = ascii.encode(uri.query);
      _queryBytesKnown = true;
    }
    return _queryBytes;
  }

  /// The percent-encoded path text.
  ///
  /// From bytes it is as received, dot segments included. From a Uri it is
  /// [Uri.path], normalized.
  String get path => _path ??= _uri?.path ?? String.fromCharCodes(_pathBytes!);

  /// The raw query text without `?`, empty when there is none.
  String get query => _query ??=
      _uri?.query ??
      (_queryBytes == null ? '' : String.fromCharCodes(_queryBytes!));

  bool get _hasQuery => _uri?.hasQuery ?? _queryBytes != null;

  /// The decoded path segments.
  ///
  /// Throws [FormatException] for a segment that does not decode.
  List<String> get pathSegments =>
      _pathSegments ??= _uri?.pathSegments ?? _splitPath(path);

  /// Splits [path] as [Uri.pathSegments] does: a leading `/` dropped, no
  /// segment for what is then empty, the rest split on `/`.
  ///
  /// A path with an escape or a backslash, which [Uri] takes as a
  /// separator, goes through [Uri] so both origins decode alike. [Uri]
  /// removes dot segments. A path split here keeps them for the router's
  /// [NormalizedPath] to remove.
  static List<String> _splitPath(String path) {
    if (path.contains('%') || path.contains(r'\')) {
      return Uri(path: path).pathSegments;
    }
    return _splitPlain(path);
  }

  /// [_splitPath] for a path without an escape or a backslash.
  static List<String> _splitPlain(String path) {
    final from = path.isNotEmpty && path.codeUnitAt(0) == 0x2f ? 1 : 0;
    if (from == path.length) return const [];
    return UnmodifiableListView(path.substring(from).split('/'));
  }

  /// The decoded query parameters.
  ///
  /// Throws [FormatException] for a parameter that does not decode.
  Map<String, List<String>> get queryParametersAll => _queryParametersAll ??=
      _uri?.queryParametersAll ??
      (_queryBytes == null ? const {} : Uri(query: query).queryParametersAll);

  /// Decodes the segments and parameters now.
  ///
  /// Throws [FormatException] for a target that does not decode, so an
  /// adapter can answer 400 before a handler runs. From bytes, a query
  /// without an escape is left for a handler that asks, since it cannot
  /// fail.
  void validate() {
    if (_uri != null) {
      pathSegments;
      queryParametersAll;
      return;
    }
    // One pass over the bytes answers what the checks below ask.
    final pathMarks = _marks(_pathBytes!);
    final queryBytes = _queryBytes;
    final queryMarks = queryBytes == null ? 0 : _marks(queryBytes);
    if ((pathMarks | queryMarks) & _fragmentMark != 0) {
      throw FormatException('A request target has no fragment', originForm);
    }
    _pathSegments ??= pathMarks & (_escapeMark | _backslashMark) == 0
        ? _splitPlain(path)
        : _splitPath(path);
    if (queryMarks & _escapeMark != 0) queryParametersAll;
  }

  static const _fragmentMark = 1;
  static const _escapeMark = 2;
  static const _backslashMark = 4;

  /// Which of `#`, `%` and `\` [bytes] holds, as marks.
  static int _marks(Uint8List bytes) {
    var marks = 0;
    for (var i = 0; i < bytes.length; i++) {
      final b = bytes[i];
      if (b == 0x23) {
        marks |= _fragmentMark;
      } else if (b == 0x25) {
        marks |= _escapeMark;
      } else if (b == 0x5c) {
        marks |= _backslashMark;
      }
    }
    return marks;
  }

  /// The encoded path, then `?` and the query when there is one.
  String get originForm => _hasQuery ? '$path?$query' : path;

  /// An absolute URL for this target under [scheme] and [authority].
  Uri toUri({required String scheme, required String authority}) =>
      Uri.parse('$scheme://$authority$originForm');

  @override
  String toString() => originForm;
}
