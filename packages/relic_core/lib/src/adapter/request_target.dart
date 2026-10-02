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
  factory RequestTarget.fromUri(final Uri uri) =>
      RequestTarget._(uri, null, null, false);

  /// The percent-encoded [path] and [query] bytes of an origin-form target.
  ///
  /// [query] excludes the `?` and is null when the target has none.
  factory RequestTarget.fromBytes(
    final Uint8List path, [
    final Uint8List? query,
  ]) => RequestTarget._(null, path, query, true);

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
  static List<String> _splitPath(final String path) {
    if (path.contains('%') || path.contains(r'\')) {
      return Uri(path: path).pathSegments;
    }
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
    if (_uri == null &&
        (_hasByte(_pathBytes!, 0x23) || _hasByte(_queryBytes, 0x23))) {
      throw FormatException('A request target has no fragment', originForm);
    }
    pathSegments;
    if (_uri != null || query.contains('%')) queryParametersAll;
  }

  static bool _hasByte(final Uint8List? bytes, final int byte) =>
      bytes != null && bytes.contains(byte);

  /// The encoded path, then `?` and the query when there is one.
  String get originForm => _hasQuery ? '$path?$query' : path;

  /// An absolute URL for this target under [scheme] and [authority].
  Uri toUri({required final String scheme, required final String authority}) =>
      Uri.parse('$scheme://$authority$originForm');

  @override
  String toString() => originForm;
}
