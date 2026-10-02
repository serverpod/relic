import 'package:meta/meta.dart';

import '../adapter/request_target.dart';

/// Represents a URL path that has been normalized.
///
/// Normalization includes:
/// - Resolving `.` and `..` segments.
/// - Removing empty segments caused by multiple consecutive slashes.
/// - Ensuring the path starts with a `/`.
///
/// Equality and [hashCode] are derived from [segments], so paths with the same
/// segments are equal regardless of how they were built. Construction does no
/// caching.
@immutable
class NormalizedPath {
  /// The individual segments of the normalized path.
  /// For example, the path `/a/b/c` would have segments `['a', 'b', 'c']`.
  final List<String> segments;

  /// Private constructor to create an instance with already normalized segments.
  NormalizedPath._(this.segments);

  /// Empty normalized path instance.
  static NormalizedPath empty = NormalizedPath._(const []);

  /// Creates a [NormalizedPath] from a given [path] string.
  ///
  /// The provided [path] is split on `/` and normalized by resolving `.` and
  /// `..` segments and removing empty ones. The path is not percent-decoded,
  /// so an encoded separator such as `%2F` stays literal within its segment;
  /// use [NormalizedPath.fromUri] to derive a path from a request.
  factory NormalizedPath(final String path) =>
      NormalizedPath._(_normalizeSegments(path.split('/')));

  /// Creates a [NormalizedPath] from segments that have already been split.
  ///
  /// Each element of [segments] is one segment and is never split further, so
  /// a separator inside a segment stays part of it rather than introducing a
  /// new one. Empty and `.` segments are dropped and `..` segments resolved,
  /// exactly as for a path string, so the result carries the same guarantee
  /// that no segment is `..`.
  factory NormalizedPath.fromSegments(final Iterable<String> segments) =>
      NormalizedPath._(_normalizeSegments(segments));

  /// Creates a [NormalizedPath] from the path of [url].
  ///
  /// [Uri.pathSegments] splits on the separator before decoding, so an encoded
  /// separator (`%2F`) stays within its segment.
  factory NormalizedPath.fromUri(final Uri url) =>
      NormalizedPath.fromPathSegments(url.pathSegments);

  /// From segments split and decoded the way [Uri.pathSegments] does it,
  /// such as [RequestTarget.pathSegments]. The unmodifiable list is reused
  /// as is when it is already normalized.
  factory NormalizedPath.fromPathSegments(final List<String> segments) {
    for (final segment in segments) {
      if (segment.isEmpty || segment == '.' || segment == '..') {
        return NormalizedPath._(_normalizeSegments(segments));
      }
    }
    return NormalizedPath._(segments);
  }

  /// Normalizes [segments] by resolving `.` and `..` and dropping empty ones.
  static List<String> _normalizeSegments(final Iterable<String> segments) {
    final result = <String>[];

    for (final segment in segments) {
      if (segment == '..') {
        if (result.isNotEmpty) {
          result.removeLast();
        }
        // Note: '..' at root is ignored
      } else if (segment != '.' && segment.isNotEmpty) {
        result.add(segment);
      }
    }
    return List.unmodifiable(result);
  }

  /// Returns a new [NormalizedPath] representing a subpath of this path.
  ///
  /// The [start] parameter specifies the starting segment index (inclusive).
  /// The optional [end] parameter specifies the ending segment index (exclusive).
  NormalizedPath subPath(final int start, [int? end]) {
    end ??= length;
    if (start == end) return NormalizedPath.empty;
    if (start == 0 && end == length) {
      return this; // since NormalizedPath is immutable
    }
    return NormalizedPath._(segments.sublist(start, end));
  }

  /// The number of segments in this path
  int get length => segments.length;

  /// Whether path has parameters or not
  late final bool hasParameters = segments.any((final s) => s.startsWith(':'));

  /// The string representation of the normalized path, always starting with `/`.
  ///
  /// For example, `NormalizedPath('a/b//c/./../d')` results in a path of `/a/b/d`.
  late final String path = '/${segments.join('/')}';

  /// Returns the normalized path string.
  @override
  String toString() => path;

  /// The hash code for this normalized path, based on its segments.
  @override
  late final int hashCode = Object.hashAll(segments);

  /// Compares this [NormalizedPath] to another object for equality.
  ///
  /// Returns true if the other object is also a [NormalizedPath] and represents the
  /// exact same sequence of path segments.
  @override
  bool operator ==(final Object other) {
    if (identical(this, other)) return true;
    if (other is! NormalizedPath) return false;

    // Fast path: compare hash codes and segment counts first
    if (hashCode != other.hashCode) return false;
    final length = segments.length;
    if (length != other.segments.length) return false;

    // Compare segments only if needed
    for (int i = 0; i < length; i++) {
      if (segments[i] != other.segments[i]) return false;
    }
    return true;
  }
}
