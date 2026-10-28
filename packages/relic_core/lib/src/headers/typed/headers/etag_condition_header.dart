import 'dart:typed_data';

import '../../../../relic_core.dart';
import '../primitives/byte_scanner.dart' show latin1Bytes;
import 'etag_header.dart' show InternalEx;
import 'wildcard_list_header.dart';

/// Base class for ETag-based conditional headers (If-Match and If-None-Match).
sealed class ETagConditionHeader extends WildcardListHeader<ETagHeader> {
  /// Creates an [ETagConditionHeader] with specific ETags.
  ETagConditionHeader.etags(super.etags);

  ETagConditionHeader._owned(super.etags) : super.owned();

  /// Creates an [ETagConditionHeader] with wildcard matching.
  const ETagConditionHeader.wildcard() : super.wildcard();

  /// The list of ETags to match against
  List<ETagHeader> get etags => values;
}

/// A class representing the HTTP If-Match header.
final class IfMatchHeader extends ETagConditionHeader {
  static const codec = HeaderCodec.fields(_parseFields, _encode);

  /// Creates an [IfMatchHeader] with specific ETags.
  IfMatchHeader.etags(super.etags) : super.etags();

  /// Creates an [IfMatchHeader] with wildcard matching.
  const IfMatchHeader.wildcard() : super.wildcard();

  IfMatchHeader._owned(super.etags) : super._owned();

  /// Parses the If-Match header [values].
  factory IfMatchHeader.parse(final Iterable<String> values) =>
      _parseFields([for (final value in values) latin1Bytes(value)]);

  /// The header from the wire bytes of its [fields].
  static IfMatchHeader _parseFields(final List<Uint8List> fields) {
    final parsed = WildcardListHeader.parseFields(
      fields,
      ETagHeader.parseElement,
    );
    if (parsed.isWildcard) return const IfMatchHeader.wildcard();
    return IfMatchHeader._owned(parsed.values);
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
  static const codec = HeaderCodec.fields(_parseFields, _encode);

  /// Creates an [IfNoneMatchHeader] with specific ETags.
  IfNoneMatchHeader.etags(super.etags) : super.etags();

  /// Creates an [IfNoneMatchHeader] with wildcard matching.
  const IfNoneMatchHeader.wildcard() : super.wildcard();

  IfNoneMatchHeader._owned(super.etags) : super._owned();

  /// Parses the If-None-Match header [values].
  factory IfNoneMatchHeader.parse(final Iterable<String> values) =>
      _parseFields([for (final value in values) latin1Bytes(value)]);

  /// The header from the wire bytes of its [fields].
  static IfNoneMatchHeader _parseFields(final List<Uint8List> fields) {
    final parsed = WildcardListHeader.parseFields(
      fields,
      ETagHeader.parseElement,
    );
    if (parsed.isWildcard) return const IfNoneMatchHeader.wildcard();
    return IfNoneMatchHeader._owned(parsed.values);
  }

  static List<String> encodeHeader(final IfNoneMatchHeader header) {
    return header.encode((final ETagHeader etag) => etag.encode()).toList();
  }

  static List<String> _encode(final IfNoneMatchHeader header) {
    return encodeHeader(header);
  }
}
