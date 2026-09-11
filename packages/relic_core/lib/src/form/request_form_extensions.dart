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
  ///
  /// This consumes the request body. It should only be called once for a request.
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

  /// Parses a request body as form data based on its Content-Type.
  ///
  /// Supports `application/x-www-form-urlencoded` and `multipart/form-data`.
  /// This consumes the request body. It should only be called once for a request.
  Future<FormData> formData({
    final FormLimits limits = FormLimits.defaults,
    final UploadStorage? uploadStorage,
    final Encoding? defaultEncoding,
  }) async {
    final contentType = headers.contentType;
    if (contentType?.mimeType == MimeType.urlEncoded) {
      return await urlEncodedForm(
        limits: limits,
        defaultEncoding: defaultEncoding,
      );
    }
    if (contentType?.mimeType == MimeType.multipartFormData) {
      return await multipartForm(
        limits: limits,
        uploadStorage: uploadStorage,
        defaultEncoding: defaultEncoding,
      );
    }
    throw const UnsupportedFormMediaTypeException(
      'Expected an HTML form request body.',
    );
  }

  /// Parses a `multipart/form-data` request body into aggregate form data.
  ///
  /// Uploaded files use [uploadStorage], or [MemoryUploadStorage] when omitted.
  /// Call [MultipartFormData.dispose] after processing uploads so storage backends
  /// can release resources, such as deleting temp files.
  ///
  /// This consumes the request body. It should only be called once for a request.
  Future<MultipartFormData> multipartForm({
    final FormLimits limits = FormLimits.defaults,
    final UploadStorage? uploadStorage,
    final Encoding? defaultEncoding,
  }) async {
    final storage = uploadStorage ?? const MemoryUploadStorage();
    final fields = <FormFieldEntry>[];
    final files = <FileFieldEntry>[];
    final entries = <FormEntry>[];
    var totalFileSize = 0;

    try {
      await for (final part in multipart(limits: limits)) {
        final name = part.name;
        if (name == null) {
          await part.discard();
          continue;
        }

        if (part.isField) {
          if (fields.length == limits.maxFieldCount) {
            throw const FormLimitExceededException(
              limit: 'maxFieldCount',
              message: 'Too many form fields.',
            );
          }

          final encoding =
              Encoding.getByName(part.contentType?.charset ?? '') ??
              defaultEncoding ??
              utf8;
          final value = await _readPartAsString(
            part,
            encoding,
            limits.maxFieldSize,
          );
          final entry = FormFieldEntry(name: name, value: value);
          fields.add(entry);
          entries.add(entry);
          continue;
        }

        if (!part.isFile) {
          await part.discard();
          continue;
        }

        if (files.length == limits.maxFileCount) {
          throw const FormLimitExceededException(
            limit: 'maxFileCount',
            message: 'Too many uploaded files.',
          );
        }

        final file = await storage.store(
          fieldName: name,
          filename: part.filename,
          contentType: part.contentType,
          headers: part.headers,
          content: _limitedFileStream(
            part.body.read(),
            limits,
            () => totalFileSize,
            (final value) => totalFileSize = value,
          ),
        );
        final entry = FileFieldEntry(name: name, file: file);
        files.add(entry);
        entries.add(entry);
      }

      return MultipartFormData(
        fields: FormFields(fields),
        files: UploadedFiles(files),
        entries: entries,
      );
    } catch (_) {
      for (final entry in files) {
        await entry.file.dispose();
      }
      rethrow;
    }
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

Future<String> _readPartAsString(
  final MultipartPart part,
  final Encoding encoding,
  final int maxLength,
) async {
  final builder = BytesBuilder(copy: false);
  await for (final chunk in part.body.read()) {
    builder.add(chunk);
    if (builder.length > maxLength) {
      throw const FormLimitExceededException(
        limit: 'maxFieldSize',
        message: 'Form field is too large.',
      );
    }
  }
  return encoding.decode(builder.takeBytes());
}

Stream<Uint8List> _limitedFileStream(
  final Stream<Uint8List> stream,
  final FormLimits limits,
  final int Function() getTotalFileSize,
  final void Function(int) setTotalFileSize,
) async* {
  var fileSize = 0;
  await for (final chunk in stream) {
    fileSize += chunk.length;
    if (fileSize > limits.maxFileSize) {
      throw const FormLimitExceededException(
        limit: 'maxFileSize',
        message: 'Uploaded file is too large.',
      );
    }

    final totalFileSize = getTotalFileSize() + chunk.length;
    if (totalFileSize > limits.maxTotalFileSize) {
      throw const FormLimitExceededException(
        limit: 'maxTotalFileSize',
        message: 'Uploaded files are too large.',
      );
    }

    setTotalFileSize(totalFileSize);
    yield chunk;
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
