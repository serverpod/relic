import 'dart:convert';

import '../body/body.dart';
import '../headers/headers.dart';
import '../headers/typed/headers/content_disposition_header.dart';
import '../headers/typed/headers/content_type_header.dart';
import 'form_data.dart';
import 'form_text.dart';

/// A streamed multipart form part.
sealed class MultipartPart {
  /// Part headers.
  final Headers headers;

  /// Parsed part Content-Disposition header, if present.
  final ContentDispositionHeader? contentDisposition;

  /// Parsed part Content-Type header, if present.
  final ContentTypeHeader? contentType;

  /// Single-read body for this part.
  final Body body;

  /// Creates the multipart part that matches the Content-Disposition in
  /// [headers].
  ///
  /// Throws [MalformedFormDataException] if the Content-Disposition or
  /// Content-Type in [headers] does not parse.
  factory MultipartPart({
    required final Headers headers,
    required final Body body,
  }) {
    final contentDisposition = _parseContentDisposition(headers);
    final contentType = _parseContentType(headers);
    final name = contentDisposition?.type.toLowerCase() == 'form-data'
        ? _contentDispositionParameter(contentDisposition, 'name')
        : null;
    if (name == null) {
      return MultipartOtherPart._(
        headers: headers,
        contentDisposition: contentDisposition,
        contentType: contentType,
        body: body,
      );
    }

    final rawFilename = _contentDispositionFilename(contentDisposition);
    if (rawFilename == null) {
      return MultipartFieldPart._(
        headers: headers,
        contentDisposition: contentDisposition,
        contentType: contentType,
        body: body,
        name: name,
      );
    }
    return MultipartFilePart._(
      headers: headers,
      contentDisposition: contentDisposition,
      contentType: contentType,
      body: body,
      name: name,
      filename: _sanitizeFilename(rawFilename),
      hasEmptyFilename: rawFilename.isEmpty,
    );
  }

  MultipartPart._({
    required this.headers,
    required this.contentDisposition,
    required this.contentType,
    required this.body,
  });

  /// Reads the part body as a string.
  ///
  /// Decodes with [encoding], or else the part charset, or else UTF-8. Throws
  /// [MalformedFormDataException] if the bytes do not decode, and
  /// [MaxBodySizeExceeded] if the body is longer than [maxLength].
  Future<String> readAsString({
    final Encoding? encoding,
    final int? maxLength,
  }) => decodeFormText(
    body.read(maxLength: maxLength),
    encoding ?? Encoding.getByName(contentType?.charset ?? '') ?? utf8,
    'Malformed multipart part',
  );

  /// Consumes and discards the part body.
  Future<void> discard() => body.read().drain<void>();
}

/// A named `form-data` part without a filename parameter.
final class MultipartFieldPart extends MultipartPart {
  /// Form field name from Content-Disposition.
  final String name;

  MultipartFieldPart._({
    required super.headers,
    required super.contentDisposition,
    required super.contentType,
    required super.body,
    required this.name,
  }) : super._();
}

/// A named `form-data` part with a `filename` or `filename*` parameter,
/// even an empty one.
final class MultipartFilePart extends MultipartPart {
  /// Form field name from Content-Disposition.
  final String name;

  /// Uploaded filename from Content-Disposition, reduced to its basename.
  ///
  /// It holds no control characters, line or paragraph separators,
  /// zero-width spaces or bidirectional formatting characters. Null when
  /// nothing usable is left, such as for an empty filename, `.`, `..` or
  /// `dir/`.
  final String? filename;

  /// Whether the filename parameter is empty, as browsers send it for a file
  /// input with no file selected.
  final bool hasEmptyFilename;

  MultipartFilePart._({
    required super.headers,
    required super.contentDisposition,
    required super.contentType,
    required super.body,
    required this.name,
    required this.filename,
    required this.hasEmptyFilename,
  }) : super._();
}

/// A part that is neither a [MultipartFieldPart] nor a [MultipartFilePart],
/// such as a part without a name or without `form-data` disposition.
final class MultipartOtherPart extends MultipartPart {
  MultipartOtherPart._({
    required super.headers,
    required super.contentDisposition,
    required super.contentType,
    required super.body,
  }) : super._();
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

String? _sanitizeFilename(final String filename) {
  final basename = _basename(filename.replaceAll(_unsafeCharacters, ''));
  if (basename.isEmpty || basename == '.' || basename == '..') return null;
  return basename;
}

/// C0 and C1 controls, line and paragraph separators, zero-width spaces and
/// bidirectional formatting characters, which can disguise a name when it is
/// displayed. Zero-width joiners and non-joiners stay, since emoji sequences
/// and scripts such as Persian need them.
final _unsafeCharacters = RegExp(
  r'[\x00-\x1f\x7f-\x9f\u061c\u200b\u200e\u200f\u2028\u2029\u202a-\u202e\u2066-\u2069\ufeff]',
);

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
