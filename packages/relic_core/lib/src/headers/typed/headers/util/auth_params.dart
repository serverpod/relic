import '../../primitives/header_scanner.dart';

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
List<(String name, String value)> parseAuthParams(final String value) {
  final params = <(String, String)>[];
  for (final part in HeaderScanner(value).splitTopLevel(_comma)) {
    if (part.isEmpty) continue;
    final scanner = HeaderScanner(part);
    final name = scanner.readToken();
    scanner.skipOws();
    scanner.expect(_equals);
    scanner.skipOws();
    final paramValue = scanner.readTokenOrQuotedString();
    scanner.skipOws();
    if (!scanner.atEnd) {
      throw FormatException(
        'unexpected characters after auth-param',
        part,
        scanner.position,
      );
    }
    params.add((name, paramValue));
  }
  return params;
}
