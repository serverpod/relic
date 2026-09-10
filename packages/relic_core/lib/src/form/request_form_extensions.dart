import 'dart:convert';
import 'dart:typed_data';

import 'package:mime/mime.dart';

import '../body/body.dart';
import '../body/types/mime_type.dart';
import '../context/result.dart';
import '../headers/headers.dart';
import '../headers/standard_headers_extensions.dart';
import 'form_data.dart';
import 'multipart_part.dart';

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

  /// Streams a `multipart/form-data` request body as individual parts.
  Stream<MultipartPart> multipart({
    final FormLimits limits = FormLimits.defaults,
  }) async* {
    final contentType = headers.contentType;
    if (contentType?.mimeType != MimeType.multipartFormData) {
      throw const UnsupportedFormMediaTypeException(
        'Expected multipart/form-data request body.',
      );
    }

    final boundary = contentType?.parameter('boundary');
    if (boundary == null || boundary.isEmpty) {
      throw const MalformedFormDataException('Missing multipart boundary.');
    }
    if (utf8.encode(boundary).length > limits.maxBoundarySize) {
      throw const FormLimitExceededException(
        limit: 'maxBoundarySize',
        message: 'Multipart boundary is too large.',
      );
    }

    var partCount = 0;
    try {
      final parts = MimeMultipartTransformer(
        boundary,
      ).bind(read(maxLength: limits.maxBodySize));

      await for (final part in parts) {
        if (partCount == limits.maxPartCount) {
          throw const FormLimitExceededException(
            limit: 'maxPartCount',
            message: 'Too many multipart parts.',
          );
        }
        partCount++;

        final headers = Headers.fromMap(
          part.headers.map((final key, final value) => MapEntry(key, [value])),
        );
        _checkPartHeaderSize(headers, limits);

        yield MultipartPart(
          headers: headers,
          body: Body.fromDataStream(_asUint8ListStream(part)),
        );
      }
    } on MimeMultipartException catch (error) {
      throw MalformedFormDataException('Malformed multipart body: $error');
    }
  }
}

void _checkPartHeaderSize(final Headers headers, final FormLimits limits) {
  var size = 0;
  for (final entry in headers.entries) {
    size += utf8.encode(entry.key).length;
    for (final value in entry.value) {
      size += utf8.encode(value).length;
    }
  }
  if (size > limits.maxPartHeaderSize) {
    throw const FormLimitExceededException(
      limit: 'maxPartHeaderSize',
      message: 'Multipart part headers are too large.',
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

Stream<Uint8List> _asUint8ListStream(final Stream<List<int>> stream) async* {
  await for (final chunk in stream) {
    if (chunk is Uint8List) {
      yield chunk;
    } else {
      yield Uint8List.fromList(chunk);
    }
  }
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
