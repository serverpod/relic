import 'dart:convert';
import 'dart:typed_data';

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
  ///
  /// Parameters with a `*`, such as `filename*`, keep the `*` in their name
  /// and their raw, undecoded value.
  final ContentDispositionHeader? contentDisposition;

  /// Single-read body for this part.
  ///
  /// [Body.bodyType] holds the part Content-Type, or null if the part has
  /// none.
  final Body body;

  /// Creates the multipart part that matches the Content-Disposition in
  /// [headers], with [content] as its body.
  ///
  /// Throws [MalformedFormDataException] if the Content-Disposition or
  /// Content-Type in [headers] does not parse.
  factory MultipartPart({
    required final Headers headers,
    required final Stream<Uint8List> content,
  }) {
    final contentDisposition = _parseContentDisposition(headers);
    final body = _body(content, _parseContentType(headers));
    final name = contentDisposition?.type.toLowerCase() == 'form-data'
        ? _contentDispositionParameter(contentDisposition, 'name')
        : null;
    if (name == null) {
      return MultipartOtherPart._(
        headers: headers,
        contentDisposition: contentDisposition,
        body: body,
      );
    }

    if (!_hasFilename(contentDisposition)) {
      return MultipartFieldPart._(
        headers: headers,
        contentDisposition: contentDisposition,
        body: body,
        name: name,
      );
    }
    final rawFilename = _contentDispositionParameter(
      contentDisposition,
      'filename',
    );
    return MultipartFilePart._(
      headers: headers,
      contentDisposition: contentDisposition,
      body: body,
      name: name,
      filename: rawFilename == null ? null : _sanitizeFilename(rawFilename),
      hasEmptyFilename: rawFilename == '',
    );
  }

  MultipartPart._({
    required this.headers,
    required this.contentDisposition,
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
    encoding ?? body.bodyType?.encoding ?? utf8,
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
    required super.body,
    required this.name,
  }) : super._();
}

/// A named `form-data` part with a `filename` or `filename*` parameter,
/// even an empty one.
final class MultipartFilePart extends MultipartPart {
  /// Form field name from Content-Disposition.
  final String name;

  /// Uploaded filename from the Content-Disposition `filename` parameter,
  /// reduced to its basename.
  ///
  /// It holds no control characters, line or paragraph separators,
  /// zero-width spaces or bidirectional formatting characters. Null when
  /// nothing usable is left, such as for an empty filename, `.`, `..` or
  /// `dir/`. Also null when the part only has `filename*`, which RFC 7578
  /// section 4.2 forbids in form data.
  final String? filename;

  /// Whether the filename parameter is empty, as browsers send it for a file
  /// input with no file selected.
  final bool hasEmptyFilename;

  MultipartFilePart._({
    required super.headers,
    required super.contentDisposition,
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
    required super.body,
  }) : super._();
}

ContentDispositionHeader? _parseContentDisposition(final Headers headers) {
  final raw = headers[Headers.contentDispositionHeader]?.firstOrNull;
  if (raw == null) return null;
  try {
    return ContentDispositionHeaderInternal.parseFormData(raw);
  } on FormatException catch (error) {
    throw MalformedFormDataException(
      'Malformed multipart Content-Disposition: ${error.message}',
    );
  }
}

/// Builds a part body with no default charset, unlike [Body.fromDataStream],
/// which defaults text to UTF-8.
///
/// It drops a declared charset that [Encoding.getByName] does not know, so
/// readers fall back to UTF-8.
Body _body(
  final Stream<Uint8List> content,
  final ContentTypeHeader? contentType,
) {
  if (contentType == null) return BodyInternal.create(content, null);
  return BodyInternal.create(
    content,
    null,
    mimeType: contentType.mimeType,
    encoding: Encoding.getByName(contentType.charset),
    parameters: {
      for (final MapEntry(:key, :value) in contentType.parameters.entries)
        if (key != 'charset') key: value,
    },
  );
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

bool _hasFilename(final ContentDispositionHeader? disposition) =>
    disposition != null &&
    disposition.parameters.any(
      (final parameter) => const {
        'filename',
        'filename*',
      }.contains(parameter.name.toLowerCase()),
    );

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
