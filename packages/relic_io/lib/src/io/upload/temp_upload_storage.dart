import 'dart:io';
import 'dart:typed_data';

import 'package:path/path.dart' as p;
import 'package:relic_core/relic_core.dart';

/// Temp-file-backed upload storage for `dart:io` applications.
///
/// [store] writes each upload to its own directory, which
/// [Directory.createTemp] creates. [TempUploadedFile.dispose] deletes that
/// directory. On POSIX systems only the current user can read it.
final class TempUploadStorage implements UploadStorage {
  /// The parent of the upload directories.
  ///
  /// When null, the upload directories go in [Directory.systemTemp].
  final Directory? directory;

  /// Prefix of every upload directory name.
  final String prefix;

  /// Creates temp-file upload storage.
  TempUploadStorage({this.directory, this.prefix = 'relic_upload_'});

  @override
  Future<UploadedFile> store({
    required final String fieldName,
    required final String? filename,
    required final ContentTypeHeader? contentType,
    required final Headers headers,
    required final Stream<Uint8List> content,
  }) async {
    final uploadDirectory = await _createUploadDirectory();
    final file = File(p.join(uploadDirectory.path, _fileName));
    final int size;

    try {
      size = await _write(file, content);
    } catch (_) {
      await _deleteQuietly(uploadDirectory);
      rethrow;
    }

    return TempUploadedFile._(
      filename: filename,
      contentType: contentType,
      headers: headers,
      directory: uploadDirectory,
      size: size,
    );
  }

  Future<Directory> _createUploadDirectory() async {
    final configured = directory;
    if (configured == null) return Directory.systemTemp.createTemp(prefix);
    await configured.create(recursive: true);
    return configured.createTemp(prefix);
  }
}

/// Uploaded file backed by a temp file on disk.
final class TempUploadedFile implements UploadedFile {
  @override
  final String? filename;

  @override
  final ContentTypeHeader? contentType;

  @override
  final Headers headers;

  /// The upload directory holding [path]. [dispose] deletes it.
  final Directory _directory;

  int? _size;
  var _disposed = false;

  TempUploadedFile._({
    required this.filename,
    required this.contentType,
    required this.headers,
    required final Directory directory,
    required final int size,
  }) : _directory = directory,
       _size = size;

  /// The path of the temp file that holds the upload.
  String get path => p.join(_directory.path, _fileName);

  @override
  int? get size => _size;

  @override
  Stream<Uint8List> read() {
    if (_disposed) {
      throw StateError('Uploaded file has been disposed.');
    }
    return _asUint8ListStream(File(path).openRead());
  }

  @override
  Future<void> dispose() async {
    if (_disposed) return;
    _disposed = true;
    _size = null;
    await _deleteQuietly(_directory);
  }
}

const _fileName = 'upload';

/// Writes [content] to [file] one chunk at a time and returns the number of
/// bytes written.
///
/// [content] stays paused while each write runs. The file closes before this
/// completes, even when [content] fails, so the caller can delete it.
/// `IOSink.addStream` does not wait for that close.
Future<int> _write(final File file, final Stream<Uint8List> content) async {
  final output = await file.open(mode: FileMode.writeOnly);
  var size = 0;
  try {
    await for (final chunk in content) {
      size += chunk.length;
      await output.writeFrom(chunk);
    }
  } catch (_) {
    await _ignoreErrors(output.close);
    rethrow;
  }
  await output.close();
  return size;
}

Future<void> _deleteQuietly(final Directory directory) async {
  try {
    await directory.delete(recursive: true);
  } on FileSystemException {
    // The caller only needs disposal/cleanup best-effort semantics.
  }
}

Future<void> _ignoreErrors(final Future<void> Function() action) async {
  try {
    await action();
  } catch (_) {
    // Ignore cleanup errors while preserving the original failure.
  }
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
