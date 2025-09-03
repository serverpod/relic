import 'package:collection/collection.dart';

import '../../../../relic.dart';
import '../../extension/string_list_extensions.dart';
import 'etag_header.dart' show InternalEx;

/// Base class for ETag-based conditional headers (If-Match and If-None-Match).
abstract class ETagConditionHeader {
  /// The list of ETags to match against.
  final List<ETagHeader> etags;

  /// Whether this is a wildcard match (*).
  final bool isWildcard;

  /// Creates an [ETagConditionHeader] with specific ETags.
  const ETagConditionHeader.etags(this.etags) : isWildcard = false;

  /// Creates an [ETagConditionHeader] with wildcard matching.
  const ETagConditionHeader.wildcard()
      : etags = const [],
        isWildcard = true;

  /// Converts the header instance to its string representation.
  String _encode() {
    if (isWildcard) return '*';
    return etags.map((final e) => e.encode()).join(', ');
  }

  @override
  bool operator ==(final Object other) =>
      identical(this, other) ||
      other is ETagConditionHeader &&
          isWildcard == other.isWildcard &&
          const ListEquality<ETagHeader>().equals(etags, other.etags);

  @override
  int get hashCode =>
      Object.hash(isWildcard, const ListEquality<ETagHeader>().hash(etags));
}

/// A class representing the HTTP If-Match header.
final class IfMatchHeader extends ETagConditionHeader {
  static const codec = HeaderCodec(IfMatchHeader.parse, __encode);
  static List<String> __encode(final IfMatchHeader value) => [value._encode()];

  /// Creates an [IfMatchHeader] with specific ETags.
  const IfMatchHeader.etags(super.etags) : super.etags();

  /// Creates an [IfMatchHeader] with wildcard matching.
  const IfMatchHeader.wildcard() : super.wildcard();

  /// Parses the If-Match header value.
  factory IfMatchHeader.parse(final Iterable<String> values) {
    final splitValues = values.splitTrimAndFilterUnique();
    if (splitValues.isEmpty) {
      throw const FormatException('Value cannot be empty');
    }

    if (splitValues.length == 1 && splitValues.first == '*') {
      return const IfMatchHeader.wildcard();
    }

    if (splitValues.length > 1 && splitValues.contains('*')) {
      throw const FormatException(
          'Wildcard (*) cannot be used with other values');
    }

    final parsedEtags = splitValues.map((final value) {
      if (!ETagHeader.isValidETag(value)) {
        throw const FormatException('Invalid ETag format');
      }
      return ETagHeader.parse(value);
    }).toList();

    return IfMatchHeader.etags(parsedEtags);
  }

  @override
  bool operator ==(final Object other) =>
      identical(this, other) ||
      other is IfMatchHeader &&
          isWildcard == other.isWildcard &&
          const ListEquality<ETagHeader>().equals(etags, other.etags);

  @override
  int get hashCode =>
      Object.hash(isWildcard, const ListEquality<ETagHeader>().hash(etags));

  @override
  String toString() => 'IfMatchHeader(etags: $etags, isWildcard: $isWildcard)';
}

/// A class representing the HTTP If-None-Match header.
final class IfNoneMatchHeader extends ETagConditionHeader {
  static const codec = HeaderCodec(IfNoneMatchHeader.parse, __encode);
  static List<String> __encode(final IfNoneMatchHeader value) =>
      [value._encode()];

  /// Creates an [IfNoneMatchHeader] with specific ETags.
  const IfNoneMatchHeader.etags(super.etags) : super.etags();

  /// Creates an [IfNoneMatchHeader] with wildcard matching.
  const IfNoneMatchHeader.wildcard() : super.wildcard();

  /// Parses the If-None-Match header value.
  factory IfNoneMatchHeader.parse(final Iterable<String> values) {
    final splitValues = values.splitTrimAndFilterUnique();
    if (splitValues.isEmpty) {
      throw const FormatException('Value cannot be empty');
    }

    if (splitValues.length == 1 && splitValues.first == '*') {
      return const IfNoneMatchHeader.wildcard();
    }

    if (splitValues.length > 1 && splitValues.contains('*')) {
      throw const FormatException(
          'Wildcard (*) cannot be used with other values');
    }

    final parsedEtags = splitValues.map((final value) {
      if (!ETagHeader.isValidETag(value)) {
        throw const FormatException('Invalid ETag format');
      }
      return ETagHeader.parse(value);
    }).toList();

    return IfNoneMatchHeader.etags(parsedEtags);
  }

  @override
  bool operator ==(final Object other) =>
      identical(this, other) ||
      other is IfNoneMatchHeader &&
          isWildcard == other.isWildcard &&
          const ListEquality<ETagHeader>().equals(etags, other.etags);

  @override
  int get hashCode =>
      Object.hash(isWildcard, const ListEquality<ETagHeader>().hash(etags));

  @override
  String toString() =>
      'IfNoneMatchHeader(etags: $etags, isWildcard: $isWildcard)';
}
