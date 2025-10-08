import 'dart:io';
import 'package:path/path.dart' as p;

import '../../../relic.dart';
import '../../adapter/context.dart';

/// Cache-busting for asset URLs that embed a content hash.
///
/// Typical flow:
/// - Outgoing URLs: call [CacheBustingConfig.assetPath] (or
///   [CacheBustingConfig.tryAssetPath]) with a known mount prefix (e.g. "/static")
///   to get "/static/name@hash.ext".
/// - Incoming requests: add this [cacheBusting] middleware so downstream
///   handlers (e.g., the static file handler) receive "/path/name.ext" without
///   the hash.
///
/// This middleware strips an inline cache-busting hash from the last path segment
/// for requests under [CacheBustingConfig.mountPrefix]. Example:
/// "/static/images/logo@abc123.png" → "/static/images/logo.png".
Middleware cacheBusting(final CacheBustingConfig config) {
  return (final inner) {
    return (final ctx) async {
      final req = ctx.request;
      final fullPath = req.requestedUri.path;

      if (!fullPath.startsWith(config.mountPrefix)) {
        return await inner(ctx);
      }

      // Extract the portion after mount prefix
      final relative = fullPath.substring(config.mountPrefix.length);
      if (relative.isEmpty) {
        return await inner(ctx);
      }
      final last = p.url.basename(relative);

      final strippedLast = _stripHashFromFilename(last, config.separator);
      if (strippedLast == last) {
        return await inner(ctx);
      }

      final directory = p.url.dirname(relative);
      final rewrittenRelative =
          directory == '.' ? strippedLast : p.url.join(directory, strippedLast);

      // Rebuild a new Request only by updating requestedUri path; do not touch
      // handlerPath so that routers and mounts continue to work as configured.
      final newRequested = req.requestedUri.replace(
        path: '${config.mountPrefix}$rewrittenRelative',
      );
      final rewrittenRequest = req.copyWith(requestedUri: newRequested);
      return await inner(rewrittenRequest.toContext(ctx.token));
    };
  };
}

/// Removes a trailing "`<sep>`hash" segment from a file name, preserving any
/// extension. Matches both "`name<sep>hash`.ext" and "`name<sep>hash`".
String _stripHashFromFilename(
  final String fileName,
  final String separator,
) {
  final ext = p.url.extension(fileName);
  final base = p.url.basenameWithoutExtension(fileName);

  final at = base.lastIndexOf(separator);
  if (at <= 0) return fileName; // no hash or starts with separator

  final cleanBase = base.substring(0, at);
  return p.url.setExtension(cleanBase, ext);
}

/// Configuration and helpers for generating cache-busted asset URLs.
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
  })  : mountPrefix = _normalizeMount(mountPrefix),
        fileSystemRoot = fileSystemRoot.absolute;

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
    final entityType =
        FileSystemEntity.typeSync(normalizedPath, followLinks: false);
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
