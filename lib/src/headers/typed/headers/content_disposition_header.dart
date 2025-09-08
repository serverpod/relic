import 'package:collection/collection.dart';

import '../../../../relic.dart';
import '../../extension/string_list_extensions.dart';

/// A class representing the HTTP Content-Disposition header.
///
/// This class manages the disposition type, such as `inline`, `attachment`,
/// or `form-data`, and optional attributes like `filename`, `name`, and
/// `filename*`. It provides functionality to parse the header value and
/// construct the appropriate header string.
final class ContentDispositionHeader {
  static const codec =
      HeaderCodec.single(ContentDispositionHeader.parse, __encode);
  static List<String> __encode(final ContentDispositionHeader value) =>
      [value._encode()];

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
  factory ContentDispositionHeader.parse(final String value) {
    final splitValues = value.splitTrimAndFilterUnique(separator: ';');

    if (splitValues.isEmpty) {
      throw const FormatException('Value cannot be empty');
    }

    final type = splitValues.first;
    if (type.isEmpty || type.contains('=')) {
      throw const FormatException('Type cannot be empty or a parameter');
    }

    final parameters =
        splitValues.skip(1).map(ContentDispositionParameter.parse).toList();

    return ContentDispositionHeader(
      type: type,
      parameters: parameters,
    );
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
          const ListEquality<ContentDispositionParameter>()
              .equals(parameters, other.parameters);

  @override
  int get hashCode => Object.hash(
      type, const ListEquality<ContentDispositionParameter>().hash(parameters));

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
    final keyValue = part.split('=').map((final e) => e.trim()).toList();

    if (keyValue.length != 2) {
      throw const FormatException('Invalid parameter format');
    }

    final name = keyValue[0];
    var value = keyValue[1].replaceAll('"', '');
    final bool isExtended = name.endsWith('*');
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
    if (isExtended) {
      return "$name*=${encoding ?? ''}'${language ?? ''}'${Uri.encodeComponent(value)}";
    }
    return '$name="$value"';
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
