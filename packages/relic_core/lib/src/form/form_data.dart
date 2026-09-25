import 'dart:async';
import 'dart:typed_data';

import '../accessor/accessor.dart';
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

/// Exception thrown when a required form field or file is absent.
final class MissingFormFieldException implements FormException {
  /// Name of the missing field.
  final String name;

  /// Creates a missing form field exception for [name].
  const MissingFormFieldException(this.name);

  @override
  String get message => 'Missing form field "$name".';

  @override
  int get statusCode => 400;

  @override
  String toString() => message;
}

/// Exception thrown when a form field value does not decode.
final class InvalidFormFieldException implements FormException {
  /// Name of the invalid field.
  final String name;

  /// The exception the decoder threw.
  final Exception error;

  /// Creates an invalid form field exception for [name].
  const InvalidFormFieldException(this.name, this.error);

  @override
  String get message => 'Invalid form field "$name".';

  @override
  int get statusCode => 400;

  @override
  String toString() => '$message $error';
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
  UploadedFiles get files => _noFiles;

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

/// A read-only accessor for a typed form field.
///
/// Use this with [FormFields] to read typed values:
/// ```dart
/// const ageField = IntFormField('age');
/// final age = form.fields.get(ageField); // typed as int
/// ```
///
/// The decoder must throw an [Exception] for an invalid value, which
/// [FormFields] reports as [InvalidFormFieldException]. An [Error] propagates
/// unchanged. Catch the [ArgumentError] from a decoder such as
/// `Enum.values.byName` and throw a [FormatException] instead.
class FormField<T extends Object> extends ReadOnlyAccessor<T, String, String> {
  const FormField(super.key, super.decode);
}

/// A form field accessor that returns the value as is.
final class StringFormField extends FormField<String> {
  const StringFormField(final String key) : super(key, _identity);
}

/// A form field accessor that parses values as [num].
final class NumFormField extends FormField<num> {
  const NumFormField(final String key) : super(key, num.parse);
}

/// A form field accessor that parses values as [int].
final class IntFormField extends FormField<int> {
  const IntFormField(final String key) : super(key, int.parse);
}

/// A form field accessor that parses values as [double].
final class DoubleFormField extends FormField<double> {
  const DoubleFormField(final String key) : super(key, double.parse);
}

/// Text form fields, read through [FormField] accessors.
///
/// [raw] maps each name to its first value. [entries] keeps every value in
/// form order, and [getAll] decodes every value for a name.
final class FormFields extends AccessorState<String, String> {
  /// Text field entries in original field order.
  final List<FormFieldEntry> entries;

  /// Creates form fields from [entries].
  factory FormFields(final Iterable<FormFieldEntry> entries) =>
      FormFields._(List.unmodifiable(entries));

  FormFields._(this.entries)
    : super(
        Map.unmodifiable({
          for (final entry in entries.reversed) entry.name: entry.value,
        }),
      );

  /// Returns the decoded first value for [accessor].
  ///
  /// Throws [MissingFormFieldException] if the field is absent, and
  /// [InvalidFormFieldException] if the value does not decode.
  @override
  T get<T extends Object>(final ReadOnlyAccessor<T, String, String> accessor) =>
      call(accessor) ?? (throw MissingFormFieldException(accessor.key));

  /// Returns the decoded first value for [accessor], or null if absent.
  ///
  /// Throws [InvalidFormFieldException] if the value does not decode.
  @override
  T? call<T extends Object>(
    final ReadOnlyAccessor<T, String, String> accessor,
  ) {
    try {
      return super.call(accessor);
    } on Exception catch (error) {
      throw InvalidFormFieldException(accessor.key, error);
    }
  }

  /// Returns every decoded value for [accessor] in form order.
  ///
  /// Throws [InvalidFormFieldException] if a value does not decode.
  List<T> getAll<T extends Object>(
    final ReadOnlyAccessor<T, String, String> accessor,
  ) {
    return [
      for (final entry in entries)
        if (entry.name == accessor.key) _decode(accessor, entry.value),
    ];
  }
}

T _decode<T extends Object>(
  final ReadOnlyAccessor<T, String, String> accessor,
  final String value,
) {
  try {
    return accessor.decode(value);
  } on Exception catch (error) {
    throw InvalidFormFieldException(accessor.key, error);
  }
}

String _identity(final String value) => value;

/// A read-only accessor for an uploaded file.
///
/// ```dart
/// const avatarFile = FormFile('avatar');
/// final avatar = form.files.get(avatarFile);
/// ```
final class FormFile
    extends ReadOnlyAccessor<UploadedFile, String, UploadedFile> {
  const FormFile(final String key) : super(key, _identityFile);
}

UploadedFile _identityFile(final UploadedFile file) => file;

/// Uploaded files, read through [FormFile] accessors.
///
/// [raw] maps each name to its first file. [entries] keeps every file in
/// form order, and [getAll] returns every file for a name.
final class UploadedFiles extends AccessorState<String, UploadedFile> {
  /// File field entries in original file order.
  final List<FileFieldEntry> entries;

  /// Creates uploaded files from [entries].
  factory UploadedFiles(final Iterable<FileFieldEntry> entries) =>
      UploadedFiles._(List.unmodifiable(entries));

  UploadedFiles._(this.entries)
    : super(
        Map.unmodifiable({
          for (final entry in entries.reversed) entry.name: entry.file,
        }),
      );

  /// Returns the first file for [accessor].
  ///
  /// Throws [MissingFormFieldException] if the form has no file for
  /// [accessor].
  @override
  T get<T extends Object>(
    final ReadOnlyAccessor<T, String, UploadedFile> accessor,
  ) => call(accessor) ?? (throw MissingFormFieldException(accessor.key));

  /// Returns every file for [accessor] in form order.
  List<UploadedFile> getAll(final FormFile accessor) => [
    for (final entry in entries)
      if (entry.name == accessor.key) entry.file,
  ];
}

final _noFiles = UploadedFiles(const []);

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
