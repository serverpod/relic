import 'dart:collection';
import 'dart:typed_data';

import 'package:http_parser/http_parser.dart';

import '../../../relic_core.dart';
import '../typed/primitives/byte_fields.dart';
import '../typed/primitives/byte_scanner.dart' show latin1Bytes;

/// Parses a URI from the given [value] and returns it as a `Uri`.
///
/// - Throws a [FormatException] if the [value] is empty or contains an invalid URI.
Uri parseUri(String value) {
  if (value.isEmpty) {
    throw const FormatException('Value cannot be empty');
  }

  try {
    return Uri.parse(value);
  } catch (e) {
    throw const FormatException('Invalid URI format');
  }
}

/// [parseUri] over the wire bytes. `Uri.parse` reads text, so the bytes
/// become a Latin-1 string first.
Uri parseUriBytes(Uint8List bytes) => parseUri(textOf(bytes));

/// Encode a Uri to a iterable of string.
Iterable<String> encodeUri(Uri uri) => [uri.toString()];

const uriHeaderCodec = HeaderCodec.bytes(parseUriBytes, encodeUri);

/// Parses a date from the given [value] and returns it as a `DateTime`.
///
/// - Throws a [FormatException] if the [value] is empty or contains an invalid date.
DateTime parseDate(String value) {
  if (value.isEmpty) {
    throw const FormatException('Value cannot be empty');
  }
  try {
    return parseHttpDate(value);
  } catch (e) {
    throw const FormatException('Invalid date format');
  }
}

/// [parseDate] over the wire bytes. `parseHttpDate` reads text, so the
/// bytes become a Latin-1 string first.
DateTime parseDateBytes(Uint8List bytes) => parseDate(textOf(bytes));

/// Encodes a DateTime to a iterable of string in HTTP date format.
Iterable<String> encodeDate(DateTime d) => [formatHttpDate(d)];

const dateTimeHeaderCodec = HeaderCodec.bytes(parseDateBytes, encodeDate);

/// Parses an integer from the given [value] and returns it as an `int`.
///
/// - Throws a [FormatException] if the [value] is empty, contains an invalid number, or is not an integer.
int parseInt(String value) {
  if (value.isEmpty) {
    throw const FormatException('Value cannot be empty');
  }

  num parsedValue;
  try {
    parsedValue = num.parse(value);
  } catch (e) {
    throw const FormatException('Invalid number');
  }

  if (parsedValue is! int) {
    throw const FormatException('Must be an integer');
  }

  return parsedValue;
}

/// Encode an integer to a iterable of string.
Iterable<String> encodeInt(int i) => [i.toString()];

/// [parseInt] over the wire bytes: a run of ASCII digits, up to 18, is
/// the int, and anything else is read as text.
int parseIntBytes(Uint8List bytes) =>
    digitsOf(bytes) ?? parseInt(textOf(bytes));

const intHeaderCodec = HeaderCodec.bytes(parseIntBytes, encodeInt);

/// Parses a positive integer from the given [value] and returns it as an `int`.
///
/// - Throws a [FormatException] if the [value] is empty, contains an invalid number, is negative, or is not an integer.
int parsePositiveInt(String value) {
  final int parsedValue = parseInt(value);
  if (parsedValue.isNegative) {
    throw const FormatException('Must be non-negative');
  }
  return parsedValue;
}

/// Encode a positive integer to a iterable of string, otherwise throws an error.
Iterable<String> encodePositiveInt(int i) =>
    i < 0 ? throw ArgumentError() : [i.toString()];

/// [parsePositiveInt] over the wire bytes.
int parsePositiveIntBytes(Uint8List bytes) =>
    digitsOf(bytes) ?? parsePositiveInt(textOf(bytes));

const positiveIntHeaderCodec = HeaderCodec.bytes(
  parsePositiveIntBytes,
  encodePositiveInt,
);

/// Parses a boolean from the given [value] and returns it as a `bool`.
///
/// - Throws a [FormatException] if the [value] is empty or contains an invalid boolean.
bool parseBool(String value) {
  if (value.isEmpty) {
    throw const FormatException('Value cannot be empty');
  }
  try {
    return bool.parse(value);
  } catch (e) {
    throw const FormatException('Invalid boolean');
  }
}

/// Parses a positive boolean from the given [value] and returns it as a `bool`.
///
/// - Throws a [FormatException] if the [value] is 'empty', 'false' or contains an invalid boolean.
bool parsePositiveBool(String value) {
  final bool parsedValue = parseBool(value);
  if (!parsedValue) {
    throw const FormatException('Must be true or null');
  }
  return parsedValue;
}

/// Encode a boolean to a iterable of string, if true.
Iterable<String> encodePositiveBool(bool b) => [if (b) b.toString()];

/// [parsePositiveBool] over the wire bytes.
bool parsePositiveBoolBytes(Uint8List bytes) =>
    parsePositiveBool(textOf(bytes));

const positiveBoolHeaderCodec = HeaderCodec.bytes(
  parsePositiveBoolBytes,
  encodePositiveBool,
);

/// Parses a string from the given [value] and returns it as a `String`.
///
/// - Throws a [FormatException] if the [value] is empty.
String parseString(String value) {
  if (value.isEmpty) {
    throw const FormatException('Value cannot be empty');
  }
  return value.trim();
}

/// [parseString] over the wire bytes: the trimmed text.
String parseStringBytes(Uint8List bytes) {
  if (bytes.isEmpty) {
    throw const FormatException('Value cannot be empty');
  }
  return textOf(trimmed(bytes));
}

/// Encode a string to a iterable of string.
Iterable<String> encodeString(String s) => [s];

const stringHeaderCodec = HeaderCodec.bytes(parseStringBytes, encodeString);

/// Parses a list of strings from the given [values] and returns it as a `List<String>`.
///
/// - Throws a [FormatException] if the resulting list is empty.
List<String> parseStringList(Iterable<String> values) =>
    parseStringListFields([for (final value in values) latin1Bytes(value)]);

/// [parseStringList] over the wire bytes of every field: the comma-separated
/// elements, trimmed, dropped when empty and kept once each.
List<String> parseStringListFields(List<Uint8List> fields) {
  final elements = splitFieldsUnique(fields);
  if (elements.isEmpty) {
    throw const FormatException('Value cannot be empty');
  }
  return List.generate(
    elements.length,
    (final i) => textOf(elements[i]),
    growable: false,
  );
}

/// Encode a list of strings to a iterable of string.
Iterable<String> encodeStringList(List<String> i) => i;

const stringListCodec = HeaderCodec.fields(
  parseStringListFields,
  encodeStringList,
);

/// [Method.parse] over the wire bytes.
Method parseMethodBytes(Uint8List bytes) => Method.parse(textOf(bytes));

Iterable<String> encodeMethod(Method m) => [m.value];
const methodCodec = HeaderCodec.bytes(parseMethodBytes, encodeMethod);

/// Parses a list of methods from the given [values] and returns it as a `List<Method>`.
///
/// - Throws a [FormatException] if the resulting list is empty.
SplayTreeSet<Method> parseMethodSet(Iterable<String> values) =>
    parseMethodSetFields([for (final value in values) latin1Bytes(value)]);

/// [parseMethodSet] over the wire bytes of every field.
SplayTreeSet<Method> parseMethodSetFields(List<Uint8List> fields) {
  final elements = splitFieldsUnique(fields);
  if (elements.isEmpty) {
    throw const FormatException('Value cannot be empty');
  }
  return SplayTreeSet.of(elements.map(parseMethodBytes), Enum.compareByIndex);
}

/// Encode a list of methods to a iterable of string.
Iterable<String> encodeMethodList(Iterable<Method> l) => l.map((r) => r.value);

const methodListCodec = HeaderCodec.fields(
  parseMethodSetFields,
  encodeMethodList,
);
