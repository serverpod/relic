import 'dart:async';
import 'dart:typed_data';

import '../body/body.dart';
import '../headers/headers.dart';
import '../headers/typed/headers/content_type_header.dart';

/// Limits used while parsing HTML forms and multipart uploads.
final class FormLimits {
  /// Maximum total request body size.
  final int maxBodySize;

  /// Maximum number of non-file fields.
  final int maxFieldCount;

  /// Maximum number of file fields.
  final int maxFileCount;

  /// Maximum number of total multipart parts.
  final int maxPartCount;

  /// Maximum byte size of a single text field.
  final int maxFieldSize;

  /// Maximum byte size of a single uploaded file.
  final int maxFileSize;

  /// Maximum byte size of all uploaded files combined.
  final int maxTotalFileSize;

  /// Maximum byte size of multipart part headers.
  final int maxPartHeaderSize;

  /// Maximum byte size of the multipart boundary.
  final int maxBoundarySize;

  /// Creates form parsing limits.
  const FormLimits({
    this.maxBodySize = 10 * 1024 * 1024,
    this.maxFieldCount = 100,
    this.maxFileCount = 8,
    this.maxPartCount = 128,
    this.maxFieldSize = 64 * 1024,
    this.maxFileSize = 10 * 1024 * 1024,
    this.maxTotalFileSize = 10 * 1024 * 1024,
    this.maxPartHeaderSize = 8 * 1024,
    this.maxBoundarySize = 200,
  });

  /// Default form parsing limits.
  static const defaults = FormLimits();

  /// Returns a copy with the given limits replaced.
  FormLimits copyWith({
    final int? maxBodySize,
    final int? maxFieldCount,
    final int? maxFileCount,
    final int? maxPartCount,
    final int? maxFieldSize,
    final int? maxFileSize,
    final int? maxTotalFileSize,
    final int? maxPartHeaderSize,
    final int? maxBoundarySize,
  }) {
    return FormLimits(
      maxBodySize: maxBodySize ?? this.maxBodySize,
      maxFieldCount: maxFieldCount ?? this.maxFieldCount,
      maxFileCount: maxFileCount ?? this.maxFileCount,
      maxPartCount: maxPartCount ?? this.maxPartCount,
      maxFieldSize: maxFieldSize ?? this.maxFieldSize,
      maxFileSize: maxFileSize ?? this.maxFileSize,
      maxTotalFileSize: maxTotalFileSize ?? this.maxTotalFileSize,
      maxPartHeaderSize: maxPartHeaderSize ?? this.maxPartHeaderSize,
      maxBoundarySize: maxBoundarySize ?? this.maxBoundarySize,
    );
  }
}

/// Base exception for form parsing failures.
sealed class FormException implements Exception {
  /// Human-readable error message.
  String get message;

  /// HTTP status code that represents this failure.
  int get statusCode;
}

/// Exception thrown when a request media type is unsupported for form parsing.
final class UnsupportedFormMediaTypeException implements FormException {
  @override
  final String message;

  /// Creates an unsupported form media type exception.
  const UnsupportedFormMediaTypeException(this.message);

  @override
  int get statusCode => 415;

  @override
  String toString() => message;
}

/// Exception thrown when form data is malformed.
final class MalformedFormDataException implements FormException {
  @override
  final String message;

  /// Creates a malformed form data exception.
  const MalformedFormDataException(this.message);

  @override
  int get statusCode => 400;

  @override
  String toString() => message;
}

/// Exception thrown when a configured form parsing limit is exceeded.
final class FormLimitExceededException implements FormException {
  @override
  final String message;

  /// The exceeded limit name.
  final String limit;

  /// Creates a form limit exceeded exception.
  const FormLimitExceededException({
    required this.limit,
    required this.message,
  });

  @override
  int get statusCode => 413;

  @override
  String toString() => message;
}

/// Parsed HTML form data.
sealed class FormData {
  /// Text field entries grouped and queried by name.
  FormFields get fields;

  /// Uploaded file entries grouped and queried by name.
  UploadedFiles get files;

  /// All form entries in original form order.
  List<FormEntry> get entries;
}

/// Parsed `application/x-www-form-urlencoded` form data.
final class UrlEncodedFormData implements FormData {
  @override
  final FormFields fields;

  @override
  UploadedFiles get files => UploadedFiles.empty;

  @override
  final List<FormEntry> entries;

  /// Creates urlencoded form data from [fields].
  UrlEncodedFormData({required this.fields})
    : entries = List.unmodifiable(fields.entries);
}

/// Parsed `multipart/form-data` form data.
final class MultipartFormData implements FormData {
  @override
  final FormFields fields;

  @override
  final UploadedFiles files;

  @override
  final List<FormEntry> entries;

  /// Creates multipart form data.
  MultipartFormData({
    required this.fields,
    required this.files,
    required final Iterable<FormEntry> entries,
  }) : entries = List.unmodifiable(entries);

  /// Disposes all uploaded files associated with this form.
  Future<void> dispose() async {
    for (final entry in files.entries) {
      await entry.file.dispose();
    }
  }
}

/// A single form entry.
sealed class FormEntry {
  /// Field name.
  String get name;
}

/// A text field entry.
final class FormFieldEntry implements FormEntry {
  @override
  final String name;

  /// Field value.
  final String value;

  /// Creates a text field entry.
  const FormFieldEntry({required this.name, required this.value});

  @override
  bool operator ==(final Object other) =>
      identical(this, other) ||
      other is FormFieldEntry && name == other.name && value == other.value;

  @override
  int get hashCode => Object.hash(name, value);

  @override
  String toString() => 'FormFieldEntry(name: $name, value: $value)';
}

/// A file field entry.
final class FileFieldEntry implements FormEntry {
  @override
  final String name;

  /// Uploaded file handle.
  final UploadedFile file;

  /// Creates a file field entry.
  const FileFieldEntry({required this.name, required this.file});
}

/// Text form fields preserving duplicate names and original field order.
final class FormFields {
  /// Empty field collection.
  static final empty = FormFields([]);

  /// Text field entries in original field order.
  final List<FormFieldEntry> entries;

  /// Creates form fields from [entries].
  FormFields(final Iterable<FormFieldEntry> entries)
    : entries = List.unmodifiable(entries);

  /// Returns the first value for [name], or null if absent.
  String? get(final String name) {
    for (final entry in entries) {
      if (entry.name == name) return entry.value;
    }
    return null;
  }

  /// Returns the first value for [name], or throws if absent.
  String getRequired(final String name) =>
      get(name) ?? (throw StateError('Missing required form field "$name".'));

  /// Returns all values for [name] in field order.
  List<String> getAll(final String name) => [
    for (final entry in entries)
      if (entry.name == name) entry.value,
  ];

  /// Returns true if any field exists for [name].
  bool contains(final String name) => get(name) != null;
}

/// Uploaded files preserving duplicate names and original file order.
final class UploadedFiles {
  /// Empty uploaded file collection.
  static final empty = UploadedFiles([]);

  /// File field entries in original file order.
  final List<FileFieldEntry> entries;

  /// Creates uploaded files from [entries].
  UploadedFiles(final Iterable<FileFieldEntry> entries)
    : entries = List.unmodifiable(entries);

  /// Returns the first file for [name], or null if absent.
  UploadedFile? get(final String name) {
    for (final entry in entries) {
      if (entry.name == name) return entry.file;
    }
    return null;
  }

  /// Returns the first file for [name], or throws if absent.
  UploadedFile getRequired(final String name) =>
      get(name) ??
      (throw StateError('Missing required uploaded file "$name".'));

  /// Returns all files for [name] in file order.
  List<UploadedFile> getAll(final String name) => [
    for (final entry in entries)
      if (entry.name == name) entry.file,
  ];

  /// Returns true if any uploaded file exists for [name].
  bool contains(final String name) => get(name) != null;
}

/// A handle to an uploaded file.
abstract interface class UploadedFile {
  /// Original filename reported by the client, if any.
  String? get filename;

  /// Content type reported for the uploaded file, if any.
  ContentTypeHeader? get contentType;

  /// Part headers associated with this upload.
  Headers get headers;

  /// Uploaded file size in bytes, if known.
  int? get size;

  /// Reads the uploaded file as a stream of bytes.
  ///
  /// Unlike [Body.read], it works any number of times until [dispose].
  /// Throws [StateError] after [dispose].
  Stream<Uint8List> read();

  /// Releases resources associated with this uploaded file.
  Future<void> dispose();
}

/// Storage backend for uploaded file parts.
abstract interface class UploadStorage {
  /// Stores [content] and returns an uploaded file handle.
  Future<UploadedFile> store({
    required String fieldName,
    required String? filename,
    required ContentTypeHeader? contentType,
    required Headers headers,
    required Stream<Uint8List> content,
  });
}

/// In-memory uploaded file storage.
final class MemoryUploadStorage implements UploadStorage {
  /// Creates in-memory upload storage.
  const MemoryUploadStorage();

  @override
  Future<UploadedFile> store({
    required final String fieldName,
    required final String? filename,
    required final ContentTypeHeader? contentType,
    required final Headers headers,
    required final Stream<Uint8List> content,
  }) async {
    final builder = BytesBuilder(copy: false);
    await for (final chunk in content) {
      builder.add(chunk);
    }
    return MemoryUploadedFile(
      filename: filename,
      contentType: contentType,
      headers: headers,
      bytes: builder.takeBytes(),
    );
  }
}

/// Uploaded file backed by memory.
final class MemoryUploadedFile implements UploadedFile {
  @override
  final String? filename;

  @override
  final ContentTypeHeader? contentType;

  @override
  final Headers headers;

  Uint8List? _bytes;

  /// Creates a memory-backed uploaded file.
  MemoryUploadedFile({
    required this.filename,
    required this.contentType,
    required this.headers,
    required final Uint8List bytes,
  }) : _bytes = Uint8List.fromList(bytes);

  @override
  int? get size => _bytes?.length;

  @override
  Stream<Uint8List> read() {
    final bytes = _bytes;
    if (bytes == null) {
      throw StateError('Uploaded file has been disposed.');
    }
    return Stream.value(bytes);
  }

  @override
  Future<void> dispose() async {
    _bytes = null;
  }
}
