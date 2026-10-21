import 'dart:collection';
import 'dart:typed_data';

import 'package:http_parser/http_parser.dart';

import '../../../relic_core.dart';
import '../extension/string_list_extensions.dart';

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

/// Encode a Uri to a iterable of string.
Iterable<String> encodeUri(Uri uri) => [uri.toString()];

const uriHeaderCodec = HeaderCodec.single(parseUri, encodeUri);

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

/// Encodes a DateTime to a iterable of string in HTTP date format.
Iterable<String> encodeDate(DateTime d) => [formatHttpDate(d)];

const dateTimeHeaderCodec = HeaderCodec.single(parseDate, encodeDate);

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

/// Parses a run of ASCII digits, or returns null for anything else so the
/// text parser decides. Up to 18 digits, which always fits an int.
int? parseIntBytes(Uint8List bytes) {
  if (bytes.isEmpty || bytes.length > 18) return null;
  var value = 0;
  for (final b in bytes) {
    if (b < 0x30 || b > 0x39) return null;
    value = value * 10 + (b - 0x30);
  }
  return value;
}

const intHeaderCodec = HeaderCodec.single(
  parseInt,
  encodeInt,
  decodeBytes: parseIntBytes,
);

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

const positiveIntHeaderCodec = HeaderCodec.single(
  parsePositiveInt,
  encodePositiveInt,
  decodeBytes: parseIntBytes,
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

const positiveBoolHeaderCodec = HeaderCodec.single(
  parsePositiveBool,
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

/// Encode a string to a iterable of string.
Iterable<String> encodeString(String s) => [s];

const stringHeaderCodec = HeaderCodec.single(parseString, encodeString);

/// Parses a list of strings from the given [values] and returns it as a `List<String>`.
///
/// - Throws a [FormatException] if the resulting list is empty.
List<String> parseStringList(Iterable<String> values) {
  final tempValues = values.splitTrimAndFilterUnique();
  if (tempValues.isEmpty) {
    throw const FormatException('Value cannot be empty');
  }
  return tempValues.toList();
}

/// Encode a list of strings to a iterable of string.
Iterable<String> encodeStringList(List<String> i) => i;

const stringListCodec = HeaderCodec(parseStringList, encodeStringList);

Iterable<String> encodeMethod(Method m) => [m.value];
const methodCodec = HeaderCodec.single(Method.parse, encodeMethod);

/// Parses a list of methods from the given [values] and returns it as a `List<Method>`.
///
/// - Throws a [FormatException] if the resulting list is empty.
SplayTreeSet<Method> parseMethodSet(Iterable<String> values) {
  final tempValues = values.splitTrimAndFilterUnique();
  if (tempValues.isEmpty) {
    throw const FormatException('Value cannot be empty');
  }
  return SplayTreeSet.of(tempValues.map(Method.parse), Enum.compareByIndex);
}

/// Encode a list of methods to a iterable of string.
Iterable<String> encodeMethodList(Iterable<Method> l) => l.map((r) => r.value);

const methodListCodec = HeaderCodec(parseMethodSet, encodeMethodList);
