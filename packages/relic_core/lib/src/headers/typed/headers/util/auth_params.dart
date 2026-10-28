import 'dart:typed_data';

import '../../primitives/byte_scanner.dart';

const int _comma = 0x2C;
const int _equals = 0x3D;

/// Parses an RFC 9110 `#auth-param` list, as used by both `Authorization`
/// credentials and `WWW-Authenticate` challenges:
///
///     auth-param = token BWS "=" BWS ( token / quoted-string )
///
/// Accepting both value forms is required because conformant peers send
/// `algorithm`/`qop`/`nc`/`stale` unquoted.
///
/// Scanning is a single linear pass over [value], so a long malformed input
/// costs time proportional to its length rather than to its length squared.
///
/// Empty list elements are ignored (RFC 9110 5.6.1.2). Throws a
/// [FormatException] if an element is not a well-formed auth-param; text
/// between parameters is rejected rather than skipped, so a value such as
/// `algorithm=MD5;evil` cannot be stored and re-emitted verbatim.
List<(String name, String value)> parseAuthParams(final Uint8List value) {
  final params = <(String, String)>[];
  for (final part in ByteScanner(value).splitTopLevel(_comma)) {
    if (part.source.isEmpty) continue;
    final name = part.readToken();
    part.skipOws();
    part.expect(_equals);
    part.skipOws();
    final paramValue = part.readTokenOrQuotedString();
    part.skipOws();
    if (!part.atEnd) {
      throw FormatException(
        'unexpected characters after auth-param',
        part.rest,
        part.position,
      );
    }
    params.add((name, paramValue));
  }
  return params;
}
