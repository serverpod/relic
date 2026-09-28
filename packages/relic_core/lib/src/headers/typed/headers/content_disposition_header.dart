import 'package:collection/collection.dart';

import '../../../../relic_core.dart';
import '../primitives/ext_value.dart';
import '../primitives/header_scanner.dart';

/// A class representing the HTTP Content-Disposition header.
///
/// This class manages the disposition type, such as `inline`, `attachment`,
/// or `form-data`, and optional attributes like `filename`, `name`, and
/// `filename*`. It provides functionality to parse the header value and
/// construct the appropriate header string.
final class ContentDispositionHeader {
  static const codec = HeaderCodec.single(
    ContentDispositionHeader.parse,
    __encode,
  );
  static List<String> __encode(final ContentDispositionHeader value) => [
    value._encode(),
  ];

  /// The disposition type, usually "inline", "attachment", or "form-data".
  final String type;

  /// A list of parameters associated with the content disposition, such as
  /// filename or name.
  final List<ContentDispositionParameter> parameters;

  /// Constructs a [ContentDispositionHeader] instance with the specified type
  /// and parameters.
  const ContentDispositionHeader({
    required this.type,
    this.parameters = const [],
  });

  /// Parses the Content-Disposition header value and returns a
  /// [ContentDispositionHeader] instance.
  ///
  /// This method splits the header by `;` and processes the type and attributes.
  ///
  /// Splitting is quote-aware, so a `;` inside a quoted parameter value is
  /// part of that value rather than a separator.
  factory ContentDispositionHeader.parse(final String value) =>
      ContentDispositionHeader._parse(value, HeaderScanner.new);

  factory ContentDispositionHeader._parse(
    final String value,
    final HeaderScanner Function(String) createScanner, {
    final bool decodeExtended = true,
  }) {
    final splitValues = createScanner(
      value,
    ).splitTopLevel(_semicolon).where((final e) => e.isNotEmpty).toList();

    if (splitValues.isEmpty) {
      throw const FormatException('Value cannot be empty');
    }

    final type = splitValues.first;
    if (type.isEmpty || type.contains('=')) {
      throw const FormatException('Type cannot be empty or a parameter');
    }

    final parameters = splitValues
        .skip(1)
        .map(
          (final part) => ContentDispositionParameter._parse(
            part,
            createScanner,
            decodeExtended: decodeExtended,
          ),
        )
        .toList();

    return ContentDispositionHeader(type: type, parameters: parameters);
  }

  /// Converts the [ContentDispositionHeader] instance into a string
  /// representation suitable for HTTP headers.
  String _encode() {
    final List<String> parts = [type];
    parts.addAll(parameters.map((final p) => p._encode()));
    return parts.join('; ');
  }

  @override
  bool operator ==(final Object other) =>
      identical(this, other) ||
      other is ContentDispositionHeader &&
          type == other.type &&
          const ListEquality<ContentDispositionParameter>().equals(
            parameters,
            other.parameters,
          );

  @override
  int get hashCode => Object.hash(
    type,
    const ListEquality<ContentDispositionParameter>().hash(parameters),
  );

  @override
  String toString() {
    return 'ContentDispositionHeader(type: $type, parameters: $parameters)';
  }
}

/// A class representing a parameter for the Content-Disposition header.
class ContentDispositionParameter {
  /// The name of the parameter (e.g., `filename`, `name`).
  final String name;

  /// The value of the parameter.
  final String value;

  /// Whether the parameter uses the RFC 8187 extended form, such as
  /// `filename*`, whose value always encodes as UTF-8.
  final bool isExtended;

  /// The language of an extended parameter, such as `en`, if it has one.
  final LanguageTag? language;

  /// Constructs a [ContentDispositionParameter] with the specified name, value,
  /// and whether it uses extended encoding.
  const ContentDispositionParameter({
    required this.name,
    required this.value,
    this.isExtended = false,
    this.language,
  });

  /// Parses a parameter string and returns a [ContentDispositionParameter]
  /// instance.
  ///
  /// Throws [FormatException] if the parameter is malformed, including an
  /// extended value that is not a UTF-8 [RFC 8187][rfc8187] `ext-value`.
  ///
  /// [rfc8187]: https://datatracker.ietf.org/doc/html/rfc8187#section-3.2
  factory ContentDispositionParameter.parse(final String part) =>
      ContentDispositionParameter._parse(part, HeaderScanner.new);

  factory ContentDispositionParameter._parse(
    final String part,
    final HeaderScanner Function(String) createScanner, {
    final bool decodeExtended = true,
  }) {
    final equals = part.indexOf('=');
    if (equals < 0) {
      throw const FormatException('Invalid parameter format');
    }

    final name = part.substring(0, equals).trim();
    final rawValue = part.substring(equals + 1).trim();
    if (name.isEmpty) {
      throw const FormatException('Invalid parameter format');
    }

    if (name.endsWith('*') && !decodeExtended) {
      return ContentDispositionParameter(name: name, value: rawValue);
    }

    if (name.endsWith('*')) {
      final extValue = ExtValue.parse(rawValue);
      return ContentDispositionParameter(
        name: name.replaceAll('*', ''),
        value: extValue.value,
        isExtended: true,
        language: extValue.language,
      );
    }

    return ContentDispositionParameter(
      name: name.replaceAll('*', ''),
      value: _readParameterValue(rawValue, createScanner),
    );
  }

  /// Converts the [ContentDispositionParameter] instance into a string
  /// representation suitable for HTTP headers.
  String _encode() {
    Token.validate(name);
    if (isExtended) {
      return '$name*=${ExtValue(value, language: language).encode()}';
    }
    return '$name=${ParameterValue(value).encode()}';
  }

  @override
  bool operator ==(final Object other) =>
      identical(this, other) ||
      other is ContentDispositionParameter &&
          name == other.name &&
          value == other.value &&
          isExtended == other.isExtended &&
          language == other.language;

  @override
  int get hashCode => Object.hash(name, value, isExtended, language);

  @override
  String toString() {
    return 'ContentDispositionParameter(name: $name, value: $value, '
        'isExtended: $isExtended, language: $language)';
  }
}

const int _semicolon = 0x3B;

/// Reads an ordinary parameter value, which is `token / quoted-string`.
String _readParameterValue(
  final String raw,
  final HeaderScanner Function(String) createScanner,
) {
  final scanner = createScanner(raw);
  final value = scanner.readTokenOrQuotedString();
  scanner.skipOws();
  if (!scanner.atEnd) {
    throw FormatException(
      'unexpected characters after parameter value',
      raw,
      scanner.position,
    );
  }
  return value;
}

/// Internal parsing for [ContentDispositionHeader], not exported from
/// relic_core.dart.
extension ContentDispositionHeaderInternal on ContentDispositionHeader {
  /// Parses the Content-Disposition [value] of a multipart form-data part,
  /// which package:mime hands over decoded from UTF-8.
  ///
  /// It leaves parameters with a `*`, such as `filename*`, undecoded and keeps
  /// the `*` in their name. RFC 7578 section 4.2 forbids them in form data.
  static ContentDispositionHeader parseFormData(final String value) =>
      ContentDispositionHeader._parse(
        value,
        HeaderScannerInternal.utf8,
        decodeExtended: false,
      );
}
