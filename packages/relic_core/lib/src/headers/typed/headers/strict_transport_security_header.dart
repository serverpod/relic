import '../../../../relic_core.dart';
import '../../extension/string_list_extensions.dart';

/// Represents the HTTP Strict-Transport-Security (HSTS) header for managing
/// HSTS settings.
final class StrictTransportSecurityHeader {
  static const codec = HeaderCodec.single(
    StrictTransportSecurityHeader.parse,
    __encode,
  );
  static List<String> __encode(final StrictTransportSecurityHeader value) => [
    value._encode(),
  ];

  /// The max-age directive specifies the time, in seconds, that the browser
  /// should remember that a site is only to be accessed using HTTPS.
  final int maxAge;

  /// The includeSubDomains directive applies this rule to all of the site's subdomains as well.
  final bool includeSubDomains;

  /// The preload directive indicates that the site is requesting inclusion
  /// in the HSTS preload list maintained by browsers.
  final bool preload;

  /// Creates a [StrictTransportSecurityHeader] with the specified [maxAge], [includeSubDomains], and [preload].
  StrictTransportSecurityHeader({
    required this.maxAge,
    this.includeSubDomains = false,
    this.preload = false,
  });

  /// Predefined directive values.
  static const _maxAgeName = 'max-age';
  static const _maxAgePrefix = '$_maxAgeName=';
  static const _includeSubDomains = 'includeSubDomains';
  static const _preload = 'preload';

  /// Parses the Strict-Transport-Security header value into a [StrictTransportSecurityHeader] instance.
  ///
  /// Throws a [FormatException] if the max-age directive is missing or invalid.
  factory StrictTransportSecurityHeader.parse(final String value) {
    final splitValues = value.splitTrimAndFilterUnique(separator: ';');
    if (splitValues.isEmpty) {
      throw const FormatException('Value cannot be empty');
    }

    int? maxAge;
    bool includeSubDomains = false;
    bool preload = false;

    // RFC 6797 6.1: directive names are case-insensitive; `max-age` is a
    // non-negative integer that may be supplied as a quoted-string. Split the
    // name from its optional value on the first `=`, tolerating OWS around it
    // (e.g. `max-age = 31536000`), and ignore unknown directives.
    for (final directive in splitValues) {
      final eq = directive.indexOf('=');
      final name = (eq < 0 ? directive : directive.substring(0, eq))
          .trim()
          .toLowerCase();
      if (name == _maxAgeName) {
        var v = eq < 0 ? '' : directive.substring(eq + 1).trim();
        if (v.length >= 2 && v.startsWith('"') && v.endsWith('"')) {
          v = v.substring(1, v.length - 1);
        }
        try {
          maxAge = DeltaSeconds.parse(v).seconds;
        } on FormatException {
          throw const FormatException(
            'Max-age directive is missing or invalid',
          );
        }
      } else if (name == _includeSubDomains.toLowerCase()) {
        includeSubDomains = true;
      } else if (name == _preload.toLowerCase()) {
        preload = true;
      }
    }

    if (maxAge == null) {
      throw const FormatException('Max-age directive is missing or invalid');
    }

    return StrictTransportSecurityHeader(
      maxAge: maxAge,
      includeSubDomains: includeSubDomains,
      preload: preload,
    );
  }

  /// Converts the [StrictTransportSecurityHeader] into a string representation
  /// for HTTP headers.

  String _encode() {
    final directives = ['$_maxAgePrefix$maxAge'];
    if (includeSubDomains) directives.add(_includeSubDomains);
    if (preload) directives.add(_preload);
    return directives.join('; ');
  }

  @override
  bool operator ==(final Object other) =>
      identical(this, other) ||
      other is StrictTransportSecurityHeader &&
          maxAge == other.maxAge &&
          includeSubDomains == other.includeSubDomains &&
          preload == other.preload;

  @override
  int get hashCode => Object.hash(maxAge, includeSubDomains, preload);

  @override
  String toString() {
    return 'StrictTransportSecurityHeader(maxAge: $maxAge, includeSubDomains: $includeSubDomains, preload: $preload)';
  }
}
