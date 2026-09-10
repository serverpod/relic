import 'dart:convert';

import '../body/types/mime_type.dart';
import '../context/result.dart';
import '../headers/standard_headers_extensions.dart';
import 'form_data.dart';

/// Form parsing helpers for [Request].
extension FormRequestExtension on Request {
  /// Parses an `application/x-www-form-urlencoded` request body.
  Future<UrlEncodedFormData> urlEncodedForm({
    final FormLimits limits = FormLimits.defaults,
    Encoding? defaultEncoding,
  }) async {
    final contentType = headers.contentType;
    if (contentType?.mimeType != MimeType.urlEncoded) {
      throw const UnsupportedFormMediaTypeException(
        'Expected application/x-www-form-urlencoded request body.',
      );
    }

    final encoding =
        Encoding.getByName(contentType?.charset ?? '') ??
        defaultEncoding ??
        utf8;
    final body = await readAsString(
      encoding: encoding,
      maxLength: limits.maxBodySize,
    );

    return UrlEncodedFormData(
      fields: FormFields(_parseUrlEncodedFields(body, encoding, limits)),
    );
  }
}

List<FormFieldEntry> _parseUrlEncodedFields(
  final String body,
  final Encoding encoding,
  final FormLimits limits,
) {
  if (body.isEmpty) return [];

  final entries = <FormFieldEntry>[];
  for (final pair in body.split('&')) {
    if (pair.isEmpty) continue;

    if (entries.length == limits.maxFieldCount) {
      throw const FormLimitExceededException(
        limit: 'maxFieldCount',
        message: 'Too many form fields.',
      );
    }

    final equals = pair.indexOf('=');
    final rawName = equals == -1 ? pair : pair.substring(0, equals);
    final rawValue = equals == -1 ? '' : pair.substring(equals + 1);
    final name = _decodeFormComponent(rawName, encoding);
    final value = _decodeFormComponent(rawValue, encoding);

    if (encoding.encode(value).length > limits.maxFieldSize) {
      throw const FormLimitExceededException(
        limit: 'maxFieldSize',
        message: 'Form field is too large.',
      );
    }

    entries.add(FormFieldEntry(name: name, value: value));
  }

  return entries;
}

String _decodeFormComponent(final String value, final Encoding encoding) {
  try {
    return Uri.decodeQueryComponent(
      value.replaceAll('+', ' '),
      encoding: encoding,
    );
  } on FormatException catch (error) {
    throw MalformedFormDataException('Malformed form data: ${error.message}');
  } on ArgumentError catch (error) {
    throw MalformedFormDataException('Malformed form data: ${error.message}');
  }
}
