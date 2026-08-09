import 'package:collection/collection.dart';

import '../../../../relic_core.dart';

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
  factory ContentDispositionHeader.parse(final String value) {
    final splitValues = HeaderScanner(
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
        .map(ContentDispositionParameter.parse)
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

  /// Whether the parameter uses extended encoding (e.g., `filename*`).
  final bool isExtended;

  /// The character encoding used, if specified (e.g., `UTF-8`).
  final String? encoding;

  /// The optional language tag, if specified (e.g., `en`).
  final String? language;

  /// Constructs a [ContentDispositionParameter] with the specified name, value,
  /// and whether it uses extended encoding.
  const ContentDispositionParameter({
    required this.name,
    required this.value,
    this.isExtended = false,
    this.encoding,
    this.language,
  });

  /// Parses a parameter string and returns a [ContentDispositionParameter]
  /// instance.
  factory ContentDispositionParameter.parse(final String part) {
    final equals = part.indexOf('=');
    if (equals < 0) {
      throw const FormatException('Invalid parameter format');
    }

    final name = part.substring(0, equals).trim();
    final rawValue = part.substring(equals + 1).trim();
    if (name.isEmpty) {
      throw const FormatException('Invalid parameter format');
    }

    final bool isExtended = name.endsWith('*');
    var value = isExtended ? rawValue : _readParameterValue(rawValue);
    String? encoding;
    String? language;

    if (isExtended) {
      /* Legal extended forms
      filename*=UTF-8'en'example.txt    // charset and language
      filename*=UTF-8''example.txt      // charset only
      filename*='en'example.txt         // language only
      filename*=''example.txt           // neither
      */
      final extendedRegex = RegExp(r"^([\w-]*)'([\w-]*)'(.*)$");
      final match = extendedRegex.firstMatch(value);
      if (match != null) {
        // match guarentees 3 groups, some may be empty
        final groups = match.groups([0, 1, 2, 3]).cast<String>();
        encoding = groups[1].nullIfEmpty;
        language = groups[2].nullIfEmpty;
        value = Uri.decodeComponent(groups[3]);
      }
    }

    return ContentDispositionParameter(
      name: name.replaceAll('*', ''),
      value: value,
      isExtended: isExtended,
      encoding: encoding,
      language: language,
    );
  }

  /// Converts the [ContentDispositionParameter] instance into a string
  /// representation suitable for HTTP headers.
  String _encode() {
    Token.validate(name);
    if (isExtended) {
      final charset = encoding;
      final lang = language;
      if (charset != null) Token.validate(charset);
      if (lang != null) Token.validate(lang);
      return "$name*=${charset ?? ''}'${lang ?? ''}'${Uri.encodeComponent(value)}";
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
          encoding == other.encoding &&
          language == other.language;

  @override
  int get hashCode => Object.hash(name, value, isExtended, encoding, language);

  @override
  String toString() {
    return 'ContentDispositionParameter(name: $name, value: $value, '
        'isExtended: $isExtended, encoding: $encoding, language: $language)';
  }
}

extension on String {
  String? get nullIfEmpty => isEmpty ? null : this;
}

const int _semicolon = 0x3B;

/// Reads an ordinary parameter value, which is `token / quoted-string`.
String _readParameterValue(final String raw) {
  final scanner = HeaderScanner(raw);
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
