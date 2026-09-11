import 'dart:convert';

import '../body/body.dart';
import '../headers/headers.dart';
import '../headers/typed/headers/content_disposition_header.dart';
import '../headers/typed/headers/content_type_header.dart';
import 'form_data.dart';

/// A streamed multipart form part.
final class MultipartPart {
  /// Part headers.
  final Headers headers;

  /// Parsed part Content-Disposition header, if present.
  final ContentDispositionHeader? contentDisposition;

  /// Parsed part Content-Type header, if present.
  final ContentTypeHeader? contentType;

  /// Form field name from Content-Disposition, if present.
  final String? name;

  /// Uploaded filename from Content-Disposition, if present.
  final String? filename;

  /// Single-read body for this part.
  final Body body;

  /// Creates a multipart part.
  factory MultipartPart({
    required final Headers headers,
    required final Body body,
  }) {
    final contentDisposition = _parseContentDisposition(headers);
    return MultipartPart._(
      headers: headers,
      contentDisposition: contentDisposition,
      contentType: _parseContentType(headers),
      name: _contentDispositionParameter(contentDisposition, 'name'),
      filename: _filename(contentDisposition),
      body: body,
    );
  }

  MultipartPart._({
    required this.headers,
    required this.contentDisposition,
    required this.contentType,
    required this.name,
    required this.filename,
    required this.body,
  });

  /// Whether this part is a non-file form field.
  bool get isField => _isFormData && name != null && filename == null;

  /// Whether this part is a file upload field.
  bool get isFile =>
      _isFormData && name != null && filename?.isNotEmpty == true;

  bool get _isFormData => contentDisposition?.type.toLowerCase() == 'form-data';

  /// Reads the part body as a string.
  Future<String> readAsString({Encoding? encoding, final int? maxLength}) {
    encoding ??= Encoding.getByName(contentType?.charset ?? '') ?? utf8;
    return encoding.decodeStream(body.read(maxLength: maxLength));
  }

  /// Consumes and discards the part body.
  Future<void> discard() => body.read().drain<void>();
}

ContentDispositionHeader? _parseContentDisposition(final Headers headers) {
  final raw = headers[Headers.contentDispositionHeader]?.firstOrNull;
  if (raw == null) return null;
  try {
    return ContentDispositionHeader.parse(raw);
  } on FormatException catch (error) {
    throw MalformedFormDataException(
      'Malformed multipart Content-Disposition: ${error.message}',
    );
  }
}

ContentTypeHeader? _parseContentType(final Headers headers) {
  final raw = headers[Headers.contentTypeHeader]?.firstOrNull;
  if (raw == null) return null;
  try {
    return ContentTypeHeader.parse(raw);
  } on FormatException catch (error) {
    throw MalformedFormDataException(
      'Malformed multipart Content-Type: ${error.message}',
    );
  }
}

String? _contentDispositionParameter(
  final ContentDispositionHeader? disposition,
  final String name,
) {
  if (disposition == null) return null;
  for (final parameter in disposition.parameters) {
    if (parameter.name.toLowerCase() == name) return parameter.value;
  }
  return null;
}

String? _filename(final ContentDispositionHeader? disposition) {
  final parameter = _contentDispositionFilename(disposition);
  if (parameter == null || parameter.isEmpty) return null;
  return _basename(parameter);
}

String? _contentDispositionFilename(
  final ContentDispositionHeader? disposition,
) {
  if (disposition == null) return null;
  ContentDispositionParameter? fallback;
  for (final parameter in disposition.parameters) {
    if (parameter.name.toLowerCase() != 'filename') continue;
    if (parameter.isExtended) return parameter.value;
    fallback ??= parameter;
  }
  return fallback?.value;
}

String _basename(final String path) {
  final slash = path.lastIndexOf('/');
  final backslash = path.lastIndexOf(r'\');
  final separator = slash > backslash ? slash : backslash;
  return separator == -1 ? path : path.substring(separator + 1);
}

extension<T> on Iterable<T> {
  T? get firstOrNull {
    final iterator = this.iterator;
    if (!iterator.moveNext()) return null;
    return iterator.current;
  }
}
