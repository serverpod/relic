import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:mime/mime.dart';

import '../body/body.dart';
import '../body/types/mime_type.dart';
import '../context/result.dart';
import '../headers/headers.dart';
import 'form_data.dart';
import 'form_text.dart';
import 'multipart_part.dart';

/// Form parsing helpers for [Request].
extension FormRequestExtension on Request {
  /// Parses an `application/x-www-form-urlencoded` request body.
  ///
  /// This consumes the request body. It should only be called once for a request.
  Future<UrlEncodedFormData> urlEncodedForm({
    final FormLimits limits = FormLimits.defaults,
  }) async {
    final bodyType = body.bodyType;
    if (bodyType?.mimeType != MimeType.urlEncoded) {
      throw const UnsupportedFormMediaTypeException(
        'Expected application/x-www-form-urlencoded request body.',
      );
    }

    final encoding = bodyType?.encoding ?? utf8;
    final text = await decodeFormText(
      _readFormBody(limits),
      encoding,
      'Malformed form data',
    );

    return UrlEncodedFormData(
      fields: FormFields(_parseUrlEncodedFields(text, encoding, limits)),
    );
  }

  /// Parses a request body as form data based on its Content-Type.
  ///
  /// Supports `application/x-www-form-urlencoded` and `multipart/form-data`.
  /// This consumes the request body. It should only be called once for a request.
  Future<FormData> formData({
    final FormLimits limits = FormLimits.defaults,
    final UploadStorage? uploadStorage,
  }) async {
    final mimeType = body.bodyType?.mimeType;
    if (mimeType == MimeType.urlEncoded) {
      return await urlEncodedForm(limits: limits);
    }
    if (mimeType == MimeType.multipartFormData) {
      return await multipartForm(limits: limits, uploadStorage: uploadStorage);
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
  /// Leaves out file parts with [MultipartFilePart.hasEmptyFilename].
  ///
  /// This consumes the request body. It should only be called once for a request.
  Future<MultipartFormData> multipartForm({
    final FormLimits limits = FormLimits.defaults,
    final UploadStorage? uploadStorage,
  }) async {
    final storage = uploadStorage ?? const MemoryUploadStorage();
    final fields = <FormFieldEntry>[];
    final files = <FileFieldEntry>[];
    final entries = <FormEntry>[];
    var totalFileSize = 0;

    try {
      await for (final part in multipart(limits: limits)) {
        switch (part) {
          case MultipartFieldPart(:final name):
            if (fields.length == limits.maxFieldCount) {
              throw const FormLimitExceededException(
                limit: FormLimit.maxFieldCount,
                message: 'Too many form fields.',
              );
            }

            final encoding = part.body.bodyType?.encoding ?? utf8;
            final value = await _readPartAsString(
              part,
              encoding,
              limits.maxFieldSize,
            );
            final entry = FormFieldEntry(name: name, value: value);
            fields.add(entry);
            entries.add(entry);

          case MultipartFilePart(hasEmptyFilename: true):
            await part.discard();

          case MultipartFilePart(:final name, :final filename):
            if (files.length == limits.maxFileCount) {
              throw const FormLimitExceededException(
                limit: FormLimit.maxFileCount,
                message: 'Too many uploaded files.',
              );
            }

            final file = await storage.store(
              fieldName: name,
              filename: filename,
              bodyType: part.body.bodyType,
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

          case MultipartOtherPart():
            await part.discard();
        }
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
    final bodyType = body.bodyType;
    if (bodyType?.mimeType != MimeType.multipartFormData) {
      throw const UnsupportedFormMediaTypeException(
        'Expected multipart/form-data request body.',
      );
    }

    final boundary = bodyType?.parameter('boundary');
    if (boundary == null || boundary.isEmpty) {
      throw const MalformedFormDataException('Missing multipart boundary.');
    }
    if (utf8.encode(boundary).length > limits.maxBoundarySize) {
      throw const FormLimitExceededException(
        limit: FormLimit.maxBoundarySize,
        message: 'Multipart boundary is too large.',
      );
    }

    yield* _parts(_readFormBody(limits), boundary, limits);
  }

  /// Reads the body, throwing [FormLimitExceededException] once it exceeds
  /// [FormLimits.maxBodySize].
  Stream<Uint8List> _readFormBody(final FormLimits limits) async* {
    try {
      await for (final chunk in read(maxLength: limits.maxBodySize)) {
        yield chunk;
      }
    } on MaxBodySizeExceeded {
      throw const FormLimitExceededException(
        limit: FormLimit.maxBodySize,
        message: 'Form body is too large.',
      );
    }
  }
}

/// Splits [body] into multipart parts.
///
/// [MimeMultipartTransformer] reports a body that fails, or ends before the
/// closing boundary, only on its stream of parts, never on the open part. A
/// consumer that reads the open part pauses that stream, so it would wait for
/// the part forever. [_parts] keeps the stream running while the consumer
/// reads a part, and fails that part with the error. Remove this workaround
/// once package:mime reports these errors on the open part.
Stream<MultipartPart> _parts(
  final Stream<Uint8List> body,
  final String boundary,
  final FormLimits limits,
) {
  final parts = StreamController<MultipartPart>();
  late final StreamSubscription<MimeMultipart> subscription;
  StreamController<Uint8List>? openPart;
  StreamSubscription<List<int>>? openMimePartSubscription;
  var partCount = 0;

  void pauseBetweenParts() {
    final part = openPart;
    final reading = part != null && part.hasListener && !part.isClosed;
    if (!reading && parts.isPaused && !subscription.isPaused) {
      subscription.pause();
    }
  }

  void fail(final Object error, final StackTrace stackTrace) {
    final mapped = error is MimeMultipartException
        ? MalformedFormDataException('Malformed multipart body: $error')
        : error;
    final part = openPart;
    if (part != null && !part.isClosed) {
      openMimePartSubscription?.cancel();
      part
        ..addError(mapped, stackTrace)
        ..close();
    }
    parts.addError(mapped, stackTrace);
  }

  void addPart(final MimeMultipart mimePart) {
    final content = StreamController<Uint8List>();
    final MultipartPart part;
    try {
      if (partCount == limits.maxPartCount) {
        throw const FormLimitExceededException(
          limit: FormLimit.maxPartCount,
          message: 'Too many multipart parts.',
        );
      }
      partCount++;

      final headers = Headers.fromMap(
        mimePart.headers.map(
          (final key, final value) => MapEntry(key, [value]),
        ),
      );
      _checkPartHeaderSize(headers, limits);
      part = MultipartPart(headers: headers, content: content.stream);
    } on FormException catch (error, stackTrace) {
      parts.addError(error, stackTrace);
      subscription.cancel();
      parts.close();
      return;
    }

    StreamSubscription<List<int>>? contentSubscription;
    content
      ..onListen = () {
        if (content.isClosed) return;
        contentSubscription = mimePart.listen(
          (final chunk) => content.add(
            chunk is Uint8List ? chunk : Uint8List.fromList(chunk),
          ),
          onError: content.addError,
          onDone: () {
            content.close();
            pauseBetweenParts();
          },
        );
        openMimePartSubscription = contentSubscription;
        if (subscription.isPaused) subscription.resume();
      }
      ..onPause = () {
        contentSubscription?.pause();
      }
      ..onResume = () {
        contentSubscription?.resume();
      }
      ..onCancel = () {
        contentSubscription?.cancel();
      };
    openPart = content;
    openMimePartSubscription = null;
    parts.add(part);
  }

  parts
    ..onListen = () {
      subscription = MimeMultipartTransformer(
        boundary,
      ).bind(body).listen(addPart, onError: fail, onDone: parts.close);
    }
    ..onPause = pauseBetweenParts
    ..onResume = () {
      if (subscription.isPaused) subscription.resume();
    }
    ..onCancel = () => subscription.cancel();
  return parts.stream;
}

Future<String> _readPartAsString(
  final MultipartPart part,
  final Encoding encoding,
  final int maxLength,
) async {
  try {
    return await decodeFormText(
      part.body.read(maxLength: maxLength),
      encoding,
      'Malformed form field',
    );
  } on MaxBodySizeExceeded {
    throw const FormLimitExceededException(
      limit: FormLimit.maxFieldSize,
      message: 'Form field is too large.',
    );
  }
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
        limit: FormLimit.maxFileSize,
        message: 'Uploaded file is too large.',
      );
    }

    final totalFileSize = getTotalFileSize() + chunk.length;
    if (totalFileSize > limits.maxTotalFileSize) {
      throw const FormLimitExceededException(
        limit: FormLimit.maxTotalFileSize,
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
      limit: FormLimit.maxPartHeaderSize,
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
        limit: FormLimit.maxFieldCount,
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
        limit: FormLimit.maxFieldSize,
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
