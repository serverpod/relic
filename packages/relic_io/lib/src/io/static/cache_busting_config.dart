import 'dart:io';
import 'package:path/path.dart' as p;

import 'static_handler.dart';

/// Cache-busting for asset URLs that embed a content hash.
///
/// Typical flow:
/// - Outgoing URLs: call [CacheBustingConfig.assetPath] (or
///   [CacheBustingConfig.tryAssetPath]) with a known mount prefix (e.g. "/static")
///   to get "/static/name@hash.ext".
/// - Incoming requests: add this [CacheBustingConfig] to the static file handler
///   (see [StaticHandler.directory]). The handler will strip the hash so that static
///   asset requests can be served without the hash.
///
/// Once added to the `createStaticHandler`, the handler will strip the hash
/// from the last path segment before looking up the file. If no hash is found,
/// the path is used as-is.
///
// Example:
/// "/static/images/logo@abc123.png" → "/static/images/logo.png".
/// "/static/images/logo.png" → "/static/images/logo.png".
class CacheBustingConfig {
  /// The URL prefix under which static assets are served (e.g., "/static").
  final String mountPrefix;

  /// Filesystem root corresponding to [mountPrefix].
  final Directory fileSystemRoot;

  /// Separator between base filename and hash (e.g., "@").
  final String separator;

  CacheBustingConfig({
    required final String mountPrefix,
    required final Directory fileSystemRoot,
    this.separator = '@',
  }) : mountPrefix = _normalizeMount(mountPrefix),
       fileSystemRoot = fileSystemRoot.absolute {
    _validateFileSystemRoot(fileSystemRoot.absolute);
    _validateSeparator(separator);
  }

  /// Returns the cache-busted URL for the given [staticPath].
  ///
  /// Example: '/static/logo.svg' → '/static/logo@hash.svg'.
  Future<String> assetPath(final String staticPath) async {
    if (!staticPath.startsWith(mountPrefix)) return staticPath;

    final relative = staticPath.substring(mountPrefix.length);
    final resolvedRootPath = fileSystemRoot.resolveSymbolicLinksSync();
    final joinedPath = p.join(resolvedRootPath, relative);
    final normalizedPath = p.normalize(joinedPath);

    // Reject traversal before hitting the filesystem
    if (!p.isWithin(resolvedRootPath, normalizedPath) &&
        normalizedPath != resolvedRootPath) {
      throw ArgumentError.value(
        staticPath,
        'staticPath',
        'must stay within $mountPrefix',
      );
    }

    // Ensure target exists (files only) before resolving symlinks
    final entityType = FileSystemEntity.typeSync(
      normalizedPath,
      followLinks: false,
    );
    if (entityType == FileSystemEntityType.notFound ||
        entityType == FileSystemEntityType.directory) {
      throw PathNotFoundException(
        normalizedPath,
        const OSError('No such file or directory', 2),
      );
    }

    final resolvedFilePath = File(normalizedPath).resolveSymbolicLinksSync();
    if (!p.isWithin(resolvedRootPath, resolvedFilePath)) {
      throw ArgumentError.value(
        staticPath,
        'staticPath',
        'must stay within $mountPrefix',
      );
    }

    final info = await getStaticFileInfo(File(resolvedFilePath));

    // Build the busted URL using URL path helpers for readability/portability
    final directory = p.url.dirname(staticPath);
    final baseName = p.url.basenameWithoutExtension(staticPath);
    final ext = p.url.extension(staticPath); // includes leading dot or ''

    final bustedName = '$baseName$separator${info.etag}$ext';
    return directory == '.'
        ? '/$bustedName'
        : p.url.join(directory, bustedName);
  }

  /// Attempts to generate a cache-busted URL. If the file cannot be found or
  /// read, returns [staticPath] unchanged.
  Future<String> tryAssetPath(final String staticPath) async {
    try {
      return await assetPath(staticPath);
    } catch (_) {
      return staticPath;
    }
  }
}

/// Ensures [mountPrefix] starts with '/' and ends with '/'.
String _normalizeMount(final String mountPrefix) {
  if (!mountPrefix.startsWith('/')) {
    throw ArgumentError('mountPrefix must start with "/"');
  }
  return mountPrefix.endsWith('/') ? mountPrefix : '$mountPrefix/';
}

void _validateFileSystemRoot(final Directory dir) {
  if (!dir.existsSync()) {
    throw ArgumentError.value(dir.path, 'fileSystemRoot', 'does not exist');
  }

  final resolved = dir.absolute.resolveSymbolicLinksSync();
  final entityType = FileSystemEntity.typeSync(resolved);
  if (entityType != FileSystemEntityType.directory) {
    throw ArgumentError.value(dir.path, 'fileSystemRoot', 'is not a directory');
  }
}

void _validateSeparator(final String separator) {
  if (separator.isEmpty) {
    throw ArgumentError('separator cannot be empty');
  }

  if (separator.contains('/')) {
    throw ArgumentError('separator cannot contain "/"');
  }
}

extension CacheBustingFilenameExtension on CacheBustingConfig {
  /// Removes a trailing "`<sep>`hash" segment from a [fileName], preserving any
  /// extension. Matches both "`name<sep>hash`.ext" and "`name<sep>hash`".
  ///
  /// If no hash is found, returns [fileName] unchanged.
  ///
  /// Examples:
  /// `logo@abc.png` -> `logo.png`
  /// `logo@abc` -> `logo`
  /// `logo.png` -> `logo.png` (no change)
  String tryStripHashFromFilename(final String fileName) {
    final ext = p.url.extension(fileName);
    final base = p.url.basenameWithoutExtension(fileName);

    final at = base.lastIndexOf(separator);
    if (at <= 0) return fileName; // no hash or starts with separator

    final cleanBase = base.substring(0, at);
    return p.url.setExtension(cleanBase, ext);
  }
}
