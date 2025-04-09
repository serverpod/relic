import 'package:http_parser/http_parser.dart';
import 'package:relic/relic.dart';
import 'package:relic/src/headers/extension/string_list_extensions.dart';
import 'package:relic/src/method/request_method.dart';

/// Parses a URI from the given [value] and returns it as a `Uri`.
///
/// - Throws a [FormatException] if the [value] is empty or contains an invalid URI.
Uri parseUri(String value) {
  if (value.isEmpty) {
    throw FormatException('Value cannot be empty');
  }

  try {
    return Uri.parse(value);
  } catch (e) {
    throw FormatException('Invalid URI format');
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
    throw FormatException('Value cannot be empty');
  }
  try {
    return parseHttpDate(value);
  } catch (e) {
    throw FormatException('Invalid date format');
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
    throw FormatException('Value cannot be empty');
  }

  num parsedValue;
  try {
    parsedValue = num.parse(value);
  } catch (e) {
    throw FormatException('Invalid number');
  }

  if (parsedValue is! int) {
    throw FormatException('Must be an integer');
  }

  return parsedValue;
}

/// Encode an integer to a iterable of string.
Iterable<String> encodeInt(int i) => [i.toString()];

const intHeaderCodec = HeaderCodec.single(parseInt, encodeInt);

/// Parses a positive integer from the given [value] and returns it as an `int`.
///
/// - Throws a [FormatException] if the [value] is empty, contains an invalid number, is negative, or is not an integer.
int parsePositiveInt(String value) {
  int parsedValue = parseInt(value);
  if (parsedValue.isNegative) {
    throw FormatException('Must be non-negative');
  }
  return parsedValue;
}

/// Encode a positive integer to a iterable of string, otherwise throws an error.
Iterable<String> encodePositiveInt(int i) =>
    i < 0 ? throw ArgumentError() : [i.toString()];

const positiveIntHeaderCodec =
    HeaderCodec.single(parsePositiveInt, encodePositiveInt);

/// Parses a boolean from the given [value] and returns it as a `bool`.
///
/// - Throws a [FormatException] if the [value] is empty or contains an invalid boolean.
bool parseBool(String value) {
  if (value.isEmpty) {
    throw FormatException('Value cannot be empty');
  }
  try {
    return bool.parse(value);
  } catch (e) {
    throw FormatException('Invalid boolean');
  }
}

/// Parses a positive boolean from the given [value] and returns it as a `bool`.
///
/// - Throws a [FormatException] if the [value] is 'empty', 'false' or contains an invalid boolean.
bool parsePositiveBool(String value) {
  bool parsedValue = parseBool(value);
  if (!parsedValue) {
    throw FormatException('Must be true or null');
  }
  return parsedValue;
}

/// Encode a boolean to a iterable of string, if true.
Iterable<String> encodePositiveBool(bool b) => [if (b) b.toString()];

const positiveBoolHeaderCodec =
    HeaderCodec.single(parsePositiveBool, encodePositiveBool);

/// Parses a string from the given [value] and returns it as a `String`.
///
/// - Throws a [FormatException] if the [value] is empty.
String parseString(String value) {
  if (value.isEmpty) {
    throw FormatException('Value cannot be empty');
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
  var tempValues = values.splitTrimAndFilterUnique();
  if (tempValues.isEmpty) {
    throw FormatException('Value cannot be empty');
  }
  return tempValues.toList();
}

/// Encode a list of strings to a iterable of string.
Iterable<String> encodeStringList(List<String> i) => i;

const stringListCodec = HeaderCodec(parseStringList, encodeStringList);

/// Parses a list of methods from the given [values] and returns it as a `List<Method>`.
///
/// - Throws a [FormatException] if the resulting list is empty.
List<RequestMethod> parseMethodList(Iterable<String> values) {
  var tempValues = values.splitTrimAndFilterUnique(emptyCheck: false);
  if (tempValues.isEmpty) {
    throw FormatException('Value cannot be empty');
  }
  return tempValues.map(RequestMethod.parse).toList();
}

/// Encode a list of methods to a iterable of string.
Iterable<String> encodeMethodList(List<RequestMethod> l) => l.map((r) => '$r');

const methodListCodec = HeaderCodec(parseMethodList, encodeMethodList);
