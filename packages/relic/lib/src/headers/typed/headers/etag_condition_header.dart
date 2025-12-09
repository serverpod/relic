import '../../../../relic.dart';
import 'etag_header.dart' show InternalEx;
import 'wildcard_list_header.dart';

/// Base class for ETag-based conditional headers (If-Match and If-None-Match).
sealed class ETagConditionHeader extends WildcardListHeader<ETagHeader> {
  /// Creates an [ETagConditionHeader] with specific ETags.
  ETagConditionHeader.etags(super.etags);

  /// Creates an [ETagConditionHeader] with wildcard matching.
  const ETagConditionHeader.wildcard() : super.wildcard();

  /// The list of ETags to match against
  List<ETagHeader> get etags => values;
}

/// A class representing the HTTP If-Match header.
final class IfMatchHeader extends ETagConditionHeader {
  static const codec = HeaderCodec(_parse, _encode);

  /// Creates an [IfMatchHeader] with specific ETags.
  IfMatchHeader.etags(super.etags) : super.etags();

  /// Creates an [IfMatchHeader] with wildcard matching.
  const IfMatchHeader.wildcard() : super.wildcard();

  /// Parses the If-Match header value.
  factory IfMatchHeader.parse(final Iterable<String> values) {
    return _parse(values);
  }

  static IfMatchHeader _parse(final Iterable<String> values) {
    final parsed = WildcardListHeader.parse(values, (final String value) {
      if (!ETagHeader.isValidETag(value)) {
        throw const FormatException('Invalid ETag format');
      }
      return ETagHeader.parse(value);
    });

    if (parsed.isWildcard) {
      return const IfMatchHeader.wildcard();
    } else {
      return IfMatchHeader.etags(parsed.values);
    }
  }

  static List<String> encodeHeader(final IfMatchHeader header) {
    return header.encode((final ETagHeader etag) => etag.encode()).toList();
  }

  static List<String> _encode(final IfMatchHeader header) {
    return encodeHeader(header);
  }
}

/// A class representing the HTTP If-None-Match header.
final class IfNoneMatchHeader extends ETagConditionHeader {
  static const codec = HeaderCodec(_parse, _encode);

  /// Creates an [IfNoneMatchHeader] with specific ETags.
  IfNoneMatchHeader.etags(super.etags) : super.etags();

  /// Creates an [IfNoneMatchHeader] with wildcard matching.
  const IfNoneMatchHeader.wildcard() : super.wildcard();

  /// Parses the If-None-Match header value.
  factory IfNoneMatchHeader.parse(final Iterable<String> values) {
    return _parse(values);
  }

  static IfNoneMatchHeader _parse(final Iterable<String> values) {
    final parsed = WildcardListHeader.parse(values, (final String value) {
      if (!ETagHeader.isValidETag(value)) {
        throw const FormatException('Invalid ETag format');
      }
      return ETagHeader.parse(value);
    });

    if (parsed.isWildcard) {
      return const IfNoneMatchHeader.wildcard();
    } else {
      return IfNoneMatchHeader.etags(parsed.values);
    }
  }

  static List<String> encodeHeader(final IfNoneMatchHeader header) {
    return header.encode((final ETagHeader etag) => etag.encode()).toList();
  }

  static List<String> _encode(final IfNoneMatchHeader header) {
    return encodeHeader(header);
  }
}
