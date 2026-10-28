import 'dart:typed_data';

import 'package:http_parser/http_parser.dart';
import '../../../../relic_core.dart';
import '../primitives/byte_fields.dart';
import '../primitives/byte_scanner.dart' show latin1Bytes;

import 'etag_header.dart';

/// A class representing the HTTP `If-Range` header.
///
/// The `If-Range` header can contain either an HTTP date or an ETag.
final class IfRangeHeader {
  static const codec = HeaderCodec.bytes(_parseBytes, __encode);
  static List<String> __encode(final IfRangeHeader value) => [value._encode()];

  /// The HTTP date if the `If-Range` header contains a date.
  final DateTime? lastModified;

  /// The ETag if the `If-Range` header contains an ETag.
  final ETagHeader? etag;

  /// Constructs an [IfRangeHeader] instance with either a date or an ETag.
  ///
  /// Either [lastModified] or [etag] must be non-null. A weak ETag is accepted
  /// but can never satisfy a range request: RFC 9110 13.1.5 requires a strong
  /// validator, so a consumer treats a weak `If-Range` as a no-match and serves
  /// the full representation rather than rejecting the request.
  IfRangeHeader({this.lastModified, this.etag}) {
    if (lastModified == null && etag == null) {
      throw const FormatException('Either date or etag must be provided');
    }
  }

  /// Parses the `If-Range` header value and returns an [IfRangeHeader] instance.
  ///
  /// Determines if the value is an ETag or a date and creates the appropriate instance.
  factory IfRangeHeader.parse(final String value) =>
      _parseBytes(latin1Bytes(value));

  /// [parse] over the wire bytes: an entity-tag, else an HTTP-date.
  static IfRangeHeader _parseBytes(final Uint8List bytes) {
    final value = trimmed(bytes);
    if (value.isEmpty) {
      throw const FormatException('Value cannot be empty');
    }
    ETagValue? etag;
    try {
      etag = ETagValue.parseBytes(value);
    } on FormatException {
      etag = null;
    }
    if (etag != null) {
      return IfRangeHeader(
        etag: ETagHeader(value: etag.value, isWeak: etag.isWeak),
      );
    }
    try {
      return IfRangeHeader(lastModified: parseHttpDate(textOf(value)));
    } catch (_) {
      throw const FormatException('Invalid format');
    }
  }

  /// Converts the [IfRangeHeader] instance into a string representation
  /// suitable for HTTP headers.

  String _encode() =>
      lastModified != null ? formatHttpDate(lastModified!) : etag!.encode();

  @override
  bool operator ==(final Object other) =>
      identical(this, other) ||
      other is IfRangeHeader &&
          lastModified == other.lastModified &&
          etag == other.etag;

  @override
  int get hashCode => Object.hash(lastModified, etag);

  @override
  String toString() {
    return 'IfRangeHeader(lastModified: $lastModified, etag: $etag)';
  }
}
