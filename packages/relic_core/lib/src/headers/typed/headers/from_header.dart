import 'dart:typed_data';

import '../../../../relic_core.dart';
import '../primitives/byte_fields.dart';
import '../primitives/byte_scanner.dart' show latin1Bytes;

/// A class representing the HTTP `From` header.
///
/// Per RFC 9110 10.1.2 the `From` header is a single `mailbox` -- the email
/// address of the human controlling the requesting user agent. The full
/// RFC 5322 `mailbox` syntax is richer than a bare `addr-spec` (it also allows
/// a `name-addr` like `Webmaster <webmaster@example.org>`, whose display-name
/// may even contain a comma), so the value is preserved verbatim rather than
/// split or format-validated.
final class FromHeader {
  static const codec = HeaderCodec.bytes(_parseBytes, __encode);
  static List<String> __encode(final FromHeader value) => [value.mailbox];

  /// The single mailbox value (RFC 9110 10.1.2 `From = mailbox`).
  final String mailbox;

  /// Constructs a [FromHeader] from a [mailbox] value.
  const FromHeader(this.mailbox);

  /// Parses a `From` header value into a [FromHeader].
  ///
  /// The value is a single mailbox; it is not split on `,` (a `display-name`
  /// may legitimately contain one) and is kept as-is, since an unparseable
  /// mailbox must not fail the request.
  factory FromHeader.parse(final String value) =>
      _parseBytes(latin1Bytes(value));

  /// [parse] over the wire bytes.
  static FromHeader _parseBytes(final Uint8List bytes) {
    final mailbox = trimmed(bytes);
    if (mailbox.isEmpty) {
      throw const FormatException('Value cannot be empty');
    }
    return FromHeader(textOf(mailbox));
  }

  @override
  bool operator ==(final Object other) =>
      identical(this, other) || other is FromHeader && mailbox == other.mailbox;

  @override
  int get hashCode => mailbox.hashCode;

  @override
  String toString() => 'FromHeader(mailbox: $mailbox)';
}
