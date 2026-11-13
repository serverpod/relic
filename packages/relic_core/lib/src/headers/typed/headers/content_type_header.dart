import 'dart:convert';
import 'dart:typed_data';

import 'package:collection/collection.dart';

import '../../../../relic_core.dart';
import '../primitives/byte_scanner.dart';

/// A class representing the HTTP Content-Type header.
final class ContentTypeHeader {
  static const codec = HeaderCodec.bytes(_parseBytes, __encode);
  static List<String> __encode(ContentTypeHeader value) => [value._encode()];

  /// The media type without parameters.
  final MimeType mimeType;

  /// Parameters associated with the media type, such as `charset` or `boundary`.
  final Map<String, String> parameters;

  /// Constructs a [ContentTypeHeader] instance with the specified MIME type and
  /// parameters.
  ContentTypeHeader({
    required this.mimeType,
    Map<String, String> parameters = const {},
  }) : parameters = Map.unmodifiable(_normalizeParameters(parameters));

  /// Takes [parameters], a map the parser built with lower-case names, as
  /// its own.
  ContentTypeHeader._(this.mimeType, this.parameters);

  /// Parses the Content-Type header value and returns a [ContentTypeHeader].
  ///
  /// The value is a media type ([RFC 9110 section 8.3.1][rfc]): a type and a
  /// subtype around a `/`, then `;`-separated `name=value` parameters whose
  /// value is a `token` or a `quoted-string`. The type, the subtype and the
  /// parameter names come out in lower case, a repeated parameter keeps its
  /// last value, and a `;` with no parameter after it is skipped.
  ///
  /// Throws [FormatException] for any other value.
  ///
  /// [rfc]: https://datatracker.ietf.org/doc/html/rfc9110#section-8.3.1
  // A multipart part header arrives decoded as UTF-8, so [value] can hold
  // any code point in a quoted parameter value.
  factory ContentTypeHeader.parse(String value) =>
      _parse(ByteScanner.utf8(utf8.encode(value)));

  /// [parse] over the wire bytes.
  static ContentTypeHeader _parseBytes(Uint8List bytes) =>
      _parse(ByteScanner(bytes));

  static ContentTypeHeader _parse(ByteScanner scanner) {
    scanner.skipOws();
    final type = scanner.readToken();
    scanner.expect(_slash);
    final subtype = scanner.readToken();
    scanner.skipOws();
    Map<String, String>? parameters;
    while (scanner.tryConsume(_semicolon)) {
      scanner.skipOws();
      // RFC 9110 5.6.6 lets a `;` stand with no parameter after it.
      if (scanner.atEnd || scanner.peek() == _semicolon) continue;
      final name = scanner.readToken();
      scanner.expect(_equals);
      (parameters ??= {})[name.toLowerCase()] = scanner
          .readTokenOrQuotedString();
      scanner.skipOws();
    }
    scanner.expectEnd('media type');
    return ContentTypeHeader._(
      MimeType(type.toLowerCase(), subtype.toLowerCase()),
      parameters == null ? const {} : UnmodifiableMapView(parameters),
    );
  }

  /// The charset parameter, if present.
  String? get charset => parameter('charset');

  /// Returns the parameter value for [name], matched case-insensitively.
  String? parameter(String name) => parameters[name.toLowerCase()];

  /// Converts the [ContentTypeHeader] instance into a string representation
  /// suitable for HTTP headers.
  String _encode() {
    mimeType.validate();
    return [
      '${mimeType.primaryType.toLowerCase()}/${mimeType.subType.toLowerCase()}',
      for (final MapEntry(:key, :value) in parameters.entries)
        '${Token.validate(key)}=${ParameterValue(value).encode()}',
    ].join('; ');
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ContentTypeHeader &&
          mimeType == other.mimeType &&
          const MapEquality<String, String>().equals(
            parameters,
            other.parameters,
          );

  @override
  int get hashCode => Object.hash(
    mimeType,
    const MapEquality<String, String>().hash(parameters),
  );

  @override
  String toString() {
    return 'ContentTypeHeader(mimeType: $mimeType, parameters: $parameters)';
  }
}

const int _slash = 0x2F;
const int _semicolon = 0x3B;
const int _equals = 0x3D;

Map<String, String> _normalizeParameters(Map<String, String> parameters) {
  return {
    for (final entry in parameters.entries)
      entry.key.toLowerCase(): entry.value,
  };
}
