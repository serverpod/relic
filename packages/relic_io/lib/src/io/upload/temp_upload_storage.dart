import 'dart:io';
import 'dart:typed_data';

import 'package:path/path.dart' as p;
import 'package:relic_core/relic_core.dart';

/// Temp-file-backed upload storage for `dart:io` applications.
final class TempUploadStorage implements UploadStorage {
  /// Directory where uploaded files are written.
  ///
  /// If omitted, a process temp directory is created lazily on first upload.
  final Directory? directory;

  /// Prefix used for lazily-created upload directories.
  final String directoryPrefix;

  Directory? _createdDirectory;
  var _counter = 0;

  /// Creates temp-file upload storage.
  TempUploadStorage({this.directory, this.directoryPrefix = 'relic_upload_'});

  @override
  Future<UploadedFile> store({
    required final String fieldName,
    required final String? filename,
    required final ContentTypeHeader? contentType,
    required final Headers headers,
    required final Stream<Uint8List> content,
  }) async {
    final file = await _createTempFile(await _directory());
    final sink = file.openWrite();
    var size = 0;

    try {
      await for (final chunk in content) {
        size += chunk.length;
        sink.add(chunk);
      }
      await sink.close();
    } catch (_) {
      await _ignoreErrors(sink.close);
      await _deleteIfExists(file);
      rethrow;
    }

    return TempUploadedFile(
      fieldName: fieldName,
      filename: filename,
      contentType: contentType,
      headers: headers,
      path: file.path,
      size: size,
    );
  }

  Future<Directory> _directory() async {
    final configured = directory;
    if (configured != null) {
      await configured.create(recursive: true);
      return configured;
    }
    return _createdDirectory ??= await Directory.systemTemp.createTemp(
      directoryPrefix,
    );
  }

  Future<File> _createTempFile(final Directory uploadDirectory) async {
    while (true) {
      final file = File(
        p.join(
          uploadDirectory.path,
          'upload_${DateTime.now().microsecondsSinceEpoch}_${_counter++}.tmp',
        ),
      );
      try {
        return await file.create(exclusive: true);
      } on PathExistsException {
        // Extremely unlikely, but avoid ever overwriting caller data.
      }
    }
  }
}

/// Uploaded file backed by a temp file on disk.
final class TempUploadedFile implements UploadedFile {
  @override
  final String fieldName;

  @override
  final String? filename;

  @override
  final ContentTypeHeader? contentType;

  @override
  final Headers headers;

  /// Temp file path.
  final String path;

  int? _size;
  var _disposed = false;

  /// Creates a temp-file-backed uploaded file.
  TempUploadedFile({
    required this.fieldName,
    required this.filename,
    required this.contentType,
    required this.headers,
    required this.path,
    required final int size,
  }) : _size = size;

  @override
  int? get size => _size;

  @override
  Stream<Uint8List> openRead() {
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
    await _deleteIfExists(File(path));
  }
}

Future<void> _deleteIfExists(final File file) async {
  try {
    await file.delete();
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
